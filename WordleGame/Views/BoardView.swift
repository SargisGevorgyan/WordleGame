//
//  BoardView.swift
//  WordleGame
//
//  The 6 x 5 grid. The active row shakes on invalid submissions.
//

import SwiftUI

struct BoardView: View {
    let board: [[Tile]]
    let currentRow: Int
    let shakeToken: Int

    var body: some View {
        VStack(spacing: 7) {
            ForEach(Array(board.enumerated()), id: \.offset) { rowIndex, row in
                HStack(spacing: 7) {
                    ForEach(Array(row.enumerated()), id: \.element.id) { columnIndex, tile in
                        TileView(tile: tile, rowIndex: rowIndex, columnIndex: columnIndex)
                    }
                }
                .shake(token: rowIndex == currentRow ? shakeToken : 0)
            }
        }
    }
}
