package com.sargisgevorgyan.wordlegame.games

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.util.Log
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import com.google.android.gms.games.PlayGames
import com.google.android.gms.games.PlayGamesSdk
import com.google.android.gms.games.SnapshotsClient
import com.google.android.gms.games.snapshot.Snapshot
import com.google.android.gms.games.snapshot.SnapshotMetadataChange
import com.google.android.gms.tasks.Task
import com.sargisgevorgyan.wordlegame.R
import com.sargisgevorgyan.wordlegame.game.Achievement
import com.sargisgevorgyan.wordlegame.game.StatsRecord
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.withContext

/**
 * Google Play Games Services (iOS: `GameCenterManager` + `CloudStatsSync`):
 * sign-in, the wins / best-streak leaderboards, achievements, and stats synced
 * through a saved game.
 *
 * The IDs live in res/values/games-ids.xml. Until that file holds the real
 * Play Console IDs the SDK is never touched and [status] stays [Status.UNAVAILABLE];
 * stats then still survive a reinstall through Android Auto Backup.
 */
class PlayGamesService(private val activity: Activity) {

    enum class Status { UNKNOWN, SIGNED_IN, SIGNED_OUT, UNAVAILABLE }

    var status by mutableStateOf(if (isConfigured(activity)) Status.UNKNOWN else Status.UNAVAILABLE)
        private set

    private val syncLock = Mutex()
    private val unlocked = mutableSetOf<Achievement>()

    /** Picks up the automatic sign-in Play Games attempts at launch. */
    suspend fun refreshSignIn() {
        if (status == Status.UNAVAILABLE) return
        status = authenticated { PlayGames.getGamesSignInClient(activity).isAuthenticated }
    }

    suspend fun signIn() {
        if (status == Status.UNAVAILABLE) return
        status = authenticated { PlayGames.getGamesSignInClient(activity).signIn() }
    }

    private suspend fun authenticated(
        call: () -> Task<com.google.android.gms.games.AuthenticationResult>,
    ): Status = try {
        if (call().await().isAuthenticated) Status.SIGNED_IN else Status.SIGNED_OUT
    } catch (e: Exception) {
        Log.w(TAG, "Sign-in check failed", e)
        Status.SIGNED_OUT
    }

    /**
     * Merges [local] with the cloud save, writes the result back and posts its
     * scores and achievements. Returns the merged stats, or null when signed out
     * or the cloud can't be reached. Runs to completion even if the caller is
     * cancelled, so a saved game is never left open.
     */
    suspend fun sync(local: StatsRecord): StatsRecord? {
        if (status != Status.SIGNED_IN) return null
        return withContext(NonCancellable) {
            syncLock.withLock {
                val merged = try {
                    syncSavedGame(local)
                } catch (e: Exception) {
                    Log.w(TAG, "Saved-game sync failed", e)
                    local
                }
                submit(merged)
                merged
            }
        }
    }

    private suspend fun syncSavedGame(local: StatsRecord): StatsRecord {
        val client = PlayGames.getSnapshotsClient(activity)
        var merged = local
        var result = client.open(SAVE_NAME, true, SnapshotsClient.RESOLUTION_POLICY_MOST_RECENTLY_MODIFIED).await()
        repeat(MAX_CONFLICT_ROUNDS) {
            val conflict = result.conflict ?: return@repeat
            merged = merged.merge(read(conflict.snapshot)).merge(read(conflict.conflictingSnapshot))
            conflict.snapshot.snapshotContents.writeBytes(merged.encode().toByteArray())
            result = client.resolveConflict(conflict.conflictId, conflict.snapshot).await()
        }
        val snapshot = result.data ?: return merged
        merged = merged.merge(read(snapshot))
        snapshot.snapshotContents.writeBytes(merged.encode().toByteArray())
        val change = SnapshotMetadataChange.Builder().setDescription(SAVE_DESCRIPTION).build()
        client.commitAndClose(snapshot, change).await()
        return merged
    }

    private fun read(snapshot: Snapshot): StatsRecord =
        StatsRecord.decode(snapshot.snapshotContents.readFully().decodeToString()) ?: StatsRecord()

    private fun submit(record: StatsRecord) {
        val stats = record.stats
        val leaderboards = PlayGames.getLeaderboardsClient(activity)
        leaderboards.submitScore(activity.getString(R.string.leaderboard_wins), stats.gamesWon.toLong())
        leaderboards.submitScore(activity.getString(R.string.leaderboard_best_streak), stats.maxStreak.toLong())
        val achievements = PlayGames.getAchievementsClient(activity)
        (Achievement.earned(stats) - unlocked).forEach {
            achievements.unlock(activity.getString(it.resId))
            unlocked += it
        }
    }

    suspend fun showLeaderboards() = show { PlayGames.getLeaderboardsClient(activity).allLeaderboardsIntent }

    suspend fun showAchievements() = show { PlayGames.getAchievementsClient(activity).achievementsIntent }

    private suspend fun show(intent: () -> Task<Intent>) {
        if (status != Status.SIGNED_IN) return
        try {
            @Suppress("DEPRECATION") // Play Games UIs need no result.
            activity.startActivityForResult(intent().await(), RC_GAMES_UI)
        } catch (e: Exception) {
            Log.w(TAG, "Couldn't open Play Games UI", e)
        }
    }

    companion object {
        private const val TAG = "PlayGames"
        private const val SAVE_NAME = "wordle-stats"
        private const val SAVE_DESCRIPTION = "Statistics and streaks"
        private const val MAX_CONFLICT_ROUNDS = 3
        private const val RC_GAMES_UI = 9001

        /** False while games-ids.xml still holds the all-zero placeholder project ID. */
        fun isConfigured(context: Context): Boolean =
            context.getString(R.string.app_id).let { id -> id.isNotBlank() && id.any { it != '0' } }

        /** Call once from Application.onCreate. */
        fun initialize(context: Context) {
            if (isConfigured(context)) PlayGamesSdk.initialize(context)
        }

        private val Achievement.resId: Int
            get() = when (this) {
                Achievement.FIRST_WIN -> R.string.achievement_first_win
                Achievement.WINS_10 -> R.string.achievement_wins_10
                Achievement.WINS_100 -> R.string.achievement_wins_100
                Achievement.STREAK_3 -> R.string.achievement_streak_3
                Achievement.STREAK_7 -> R.string.achievement_streak_7
                Achievement.STREAK_30 -> R.string.achievement_streak_30
            }
    }
}
