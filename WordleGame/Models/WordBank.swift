//
//  WordBank.swift
//  WordleGame
//
//  Built-in word lists so the game works completely offline.
//  All words are stored / compared in UPPERCASE (works for English and Armenian).
//  Every entry is exactly 5 letters (Armenian: 5 letters with the ու digraph
//  counted as one). Access them through `GameLanguage` rather than directly.
//

import Foundation

enum WordBank {

    // MARK: - English (642 five-letter words)

    static let english: [String] = [
        "ABOUT", "ABOVE", "ABUSE", "ACTOR", "ACUTE", "ADMIT", "ADOPT", "ADULT", "AFTER", "AGAIN",
        "AGENT", "AGREE", "AHEAD", "ALARM", "ALBUM", "ALERT", "ALIEN", "ALIGN", "ALIKE", "ALIVE",
        "ALLOW", "ALLOY", "ALONE", "ALONG", "ALOUD", "ALTER", "AMONG", "AMUSE", "ANGER", "ANGLE",
        "ANGRY", "ANKLE", "ANNOY", "APART", "APPLE", "APPLY", "ARENA", "ARGUE", "ARISE", "ARMOR",
        "ARRAY", "ARROW", "ASIDE", "ASSET", "AUDIO", "AUDIT", "AVOID", "AWAKE", "AWARE", "BADGE",
        "BADLY", "BAKER", "BASIC", "BASIN", "BASIS", "BEACH", "BEARD", "BEAST", "BEGIN", "BEING",
        "BELOW", "BENCH", "BENEF", "BLACK", "BLADE", "BLAME", "BLANK", "BLAST", "BLAZE", "BLEED",
        "BLEND", "BLESS", "BLIND", "BLOCK", "BLOOD", "BLOOM", "BOARD", "BOAST", "BONUS", "BOOST",
        "BOOTH", "BOUND", "BRAIN", "BRAKE", "BRAND", "BRAVE", "BREAD", "BREAK", "BREED", "BRICK",
        "BRIDE", "BRIEF", "BRING", "BROAD", "BROWN", "BRUSH", "BUDDY", "BUILD", "BUNCH", "BUYER",
        "CABLE", "CANDY", "CARGO", "CARRY", "CARVE", "CATCH", "CAUSE", "CHAIN", "CHAIR", "CHALK",
        "CHAOS", "CHARM", "CHART", "CHASE", "CHEAP", "CHECK", "CHEEK", "CHEER", "CHESS", "CHEST",
        "CHIEF", "CHILD", "CHILL", "CHINA", "CHOIR", "CHOKE", "CHORD", "CHOSE", "CIVIC", "CIVIL",
        "CLAIM", "CLASS", "CLEAN", "CLEAR", "CLIMB", "CLOCK", "CLOSE", "CLOTH", "CLOUD", "COACH",
        "COAST", "COUNT", "COURT", "COVER", "CRACK", "CRAFT", "CRANE", "CRASH", "CRAWL", "CRAZY",
        "CREAM", "CREED", "CRIME", "CRISP", "CROWD", "CROWN", "CRUDE", "CRUEL", "CRUSH", "CRUST",
        "CRYST", "CURVE", "CYCLE", "DAILY", "DANCE", "DRAFT", "DRAIN", "DRAMA", "DRANK", "DRAWN",
        "DREAM", "DRESS", "DRIFT", "DRILL", "DRINK", "DRIVE", "DROWN", "DRUNG", "DUSTY", "EAGER",
        "EAGLE", "EARLY", "EARTH", "EASEL", "EATEN", "EIGHT", "ELBOW", "ELITE", "EMPTY", "ENEMY",
        "ENJOY", "ENTER", "ENTRY", "EQUAL", "EQUIP", "ERROR", "EVENT", "EVERY", "EXACT", "EXERT",
        "EXILE", "EXIST", "EXTRA", "FAITH", "FALSE", "FANCY", "FATAL", "FAULT", "FAVOR", "FEAST",
        "FIBER", "FIELD", "FIFTH", "FIFTY", "FIGHT", "FINAL", "FIRST", "FLAME", "FLASH", "FLEET",
        "FLESH", "FLOAT", "FLOCK", "FLOOD", "FLOOR", "FLOUR", "FLUID", "FLUSH", "FLUTE", "FOCUS",
        "FORCE", "FORUM", "FOUND", "FRAME", "FRAUD", "FRESH", "FRONT", "FROST", "FRUIT", "FUNNY",
        "GHOST", "GIANT", "GIVEN", "GLASS", "GLOBE", "GLORY", "GLOVE", "GRACE", "GRADE", "GRAIN",
        "GRAND", "GRANT", "GRAPE", "GRAPH", "GRASP", "GRASS", "GRAVE", "GREAT", "GREEN", "GREET",
        "GRIEF", "GRILL", "GRIND", "GROSS", "GROUP", "GROVE", "GROWN", "GUARD", "GUESS", "GUEST",
        "GUIDE", "GUILD", "GUILT", "HABIT", "HAPPY", "HARSH", "HEART", "HEAVY", "HEDGE", "HELLO",
        "HONOR", "HORSE", "HOTEL", "HOUSE", "HUMAN", "HUMOR", "IDEAL", "IMAGE", "IMPLY", "INDEX",
        "INNER", "INPUT", "ISSUE", "JAPAN", "JEWEL", "JOINT", "JUDGE", "JUICE", "KNIFE", "KNOCK",
        "LABEL", "LABOR", "LARGE", "LATER", "LAUGH", "LAYER", "LEARN", "LEASE", "LEAST", "LEMON",
        "LEVEL", "LEVER", "LIGHT", "LIMIT", "LINEN", "LOCAL", "LOGIC", "LOOSE", "LOWER", "LOYAL",
        "LUCKY", "LUNAR", "LUNCH", "MAGIC", "MAJOR", "MAKER", "MARCH", "MATCH", "MAYOR", "MEDAL",
        "MEDIA", "MERCY", "MERIT", "METAL", "METER", "MICRO", "MIGHT", "MINOR", "MINUS", "MODEL",
        "MODEM", "MONEY", "MONTH", "MORAL", "MOTOR", "MOUNT", "MOUSE", "MOUTH", "MOVIE", "MUSIC",
        "NAKED", "NERVE", "NEVER", "NEWLY", "NIGHT", "NOBLE", "NOISE", "NORTH", "NOVEL", "NURSE",
        "OCEAN", "OFFER", "OFTEN", "OLIVE", "ONION", "ORBIT", "ORDER", "ORGAN", "OTHER", "OUTER",
        "OWNER", "OZONE", "PAINT", "PANEL", "PANIC", "PAPER", "PARTY", "PEACE", "PEACH", "PEARL",
        "PENAL", "PENNY", "PHASE", "PHONE", "PHOTO", "PIANO", "PIECE", "PILOT", "PITCH", "PIZZA",
        "PLACE", "PLAIN", "PLANE", "PLANT", "PLATE", "POINT", "POKER", "POLAR", "POWER", "PRESS",
        "PRICE", "PRIDE", "PRIME", "PRINT", "PRIOR", "PRIZE", "PROOF", "PROUD", "PROVE", "PULSE",
        "PUPIL", "PURSE", "QUEEN", "QUEST", "QUICK", "QUIET", "QUITE", "QUOTA", "RADIO", "RAISE",
        "RANGE", "RAPID", "RATIO", "REACH", "REACT", "READY", "REALM", "REBEL", "REFER", "RELAX",
        "RENEW", "REPLY", "RESET", "RESIN", "RIDER", "RIDGE", "RIFLE", "RIGHT", "RIGID", "RIVAL",
        "RIVER", "ROBOT", "ROUGH", "ROUND", "ROUTE", "ROYAL", "RULER", "RURAL", "SAINT", "SALAD",
        "SALES", "SALON", "SAUCE", "SCALE", "SCENE", "SCENT", "SCOPE", "SCORE", "SENSE", "SERUM",
        "SERVE", "SEVEN", "SHADE", "SHAKE", "SHAME", "SHAPE", "SHARE", "SHARK", "SHARP", "SHEEP",
        "SHEER", "SHEET", "SHELL", "SHIFT", "SHINE", "SHIRT", "SHOCK", "SHOOT", "SHORT", "SHOUT",
        "SIGHT", "SIGMA", "SINCE", "SKILL", "SKIRT", "SKULL", "SLATE", "SLAVE", "SLEEP", "SLICE",
        "SLIDE", "SLOPE", "SMART", "SMELL", "SMILE", "SMOKE", "SNAKE", "SOLAR", "SOLID", "SOLVE",
        "SORRY", "SOUND", "SOUTH", "SPACE", "SPARE", "SPARK", "SPEAK", "SPEED", "SPELL", "SPEND",
        "SPICE", "SPILL", "SPINE", "SPITE", "SPLIT", "SPOON", "SPORT", "SPRAY", "SQUAD", "STACK",
        "STAFF", "STAGE", "STAIN", "STAKE", "STAMP", "STAND", "STARE", "START", "STATE", "STEAM",
        "STEEL", "STEEP", "STEER", "STICK", "STIFF", "STILL", "STOCK", "STONE", "STORE", "STORM",
        "STORY", "STRIP", "STUDY", "STUFF", "STYLE", "SUGAR", "SUITE", "SUPER", "SWEET", "SWIFT",
        "SWING", "SWORD", "TABLE", "TASTE", "TEACH", "THEME", "THERE", "THICK", "THING", "THINK",
        "THIRD", "THORN", "THOSE", "THREE", "THROW", "TIGER", "TIGHT", "TITLE", "TODAY", "TOKEN",
        "TOTAL", "TOUCH", "TOUGH", "TOWER", "TOXIC", "TRACK", "TRADE", "TRAIN", "TRAIT", "TRASH",
        "TREAT", "TREND", "TRIAL", "TRIBE", "TRICK", "TRUCK", "TRULY", "TRUNK", "TRUST", "TRUTH",
        "TUMOR", "TWICE", "TWIST", "ULTRA", "UNCLE", "UNDER", "UNION", "UNITE", "UNITY", "UNTIL",
        "UPPER", "UPSET", "URBAN", "USAGE", "USUAL", "VALID", "VALUE", "VALVE", "VAPOR", "VIDEO",
        "VIRUS", "VISIT", "VITAL", "VIVID", "VOCAL", "VOICE", "WAGON", "WATER", "WEARY", "WHEAT",
        "WHEEL", "WHERE", "WHICH", "WHILE", "WHITE", "WHOLE", "WHOSE", "WOMAN", "WORLD", "WORRY",
        "WORSE", "WORST", "WORTH", "WOULD", "WOUND", "WRITE", "WRONG", "YACHT", "YIELD", "YOUNG",
        "YOUTH", "ZEBRA"
    ]

    // MARK: - Armenian (430 five-letter words, uppercase; ու = one letter)

    static let armenian: [String] = [
        "ԱԲԵՂԱ", "ԱԲՈՆԵ", "ԱԲՐԱՀ", "ԱԳԱՀԻ", "ԱԳԱՐԱ", "ԱԴԱՄԱ", "ԱԴԱՄԻ", "ԱԶԱՏԻ", "ԱԶԴԱԿ", "ԱԼԲՈՄ",
        "ԱԼԻՔՍ", "ԱԽՈՌԻ", "ԱԽՏԵՐ", "ԱԿԱՆՋ", "ԱԿՆՈՑ", "ԱԿՈՒՄԲ", "ԱՂԱԽԻ", "ԱՂԱՎՆ", "ԱՂԲՅՈՒ", "ԱՂԹԱՄ",
        "ԱՂՏՈՏ", "ԱՄԲՈԽ", "ԱՄՊԵՐ", "ԱՅԳԻՆ", "ԱՅՑԵԼ", "ԱՆԱՊԱ", "ԱՆԴԱՄ", "ԱՆԿՅՈՒ", "ԱՆՁՐԵ", "ԱՆՄԱՀ",
        "ԱՆՎԱՆ", "ԱՆՏԱՌ", "ԱՇԽԱՐ", "ԱՊԱԿԻ", "ԱՊԱՑՈ", "ԱՊՐԵԼ", "ԱՌԱՎՈ", "ԱՍԼԱՆ", "ԱՍՏՂԻ", "ԱՍՏՎԱ",
        "ԱՎԱԳԻ", "ԱՎԱԶԻ", "ԱՎԱՆԴ", "ԱՎԵԼԻ", "ԱՎԵՏԻ", "ԱՎՏՈՄ", "ԱՏԱՄՆ", "ԱՐԱԳՈ", "ԱՐԱՐԱ", "ԱՐԴՅՈ",
        "ԱՐԵԱՆ", "ԱՐԵՎԵ", "ԱՐԵՎՍ", "ԱՐԽԻՎ", "ԱՐԾԻՎ", "ԱՐՁԱՆ", "ԱՐՄԱՏ", "ԱՐՋԻՆ", "ԲԱԳԻՆ", "ԲԱԳՐԱ",
        "ԲԱԺԱԿ", "ԲԱԺԱՆ", "ԲԱԺԻՆ", "ԲԱԼԵՆ", "ԲԱԽՏԻ", "ԲԱԿԵՐ", "ԲԱՂՆԻ", "ԲԱՄԲԱ", "ԲԱՆԱԼ", "ԲԱՆԱԿ",
        "ԲԱՆՏԱ", "ԲԱՆՏԻ", "ԲԱՌԵՐ", "ԲԱՐԵԼ", "ԲԱՐԵԿ", "ԲԱՐԻՆ", "ԲԱՐՁՐ", "ԲԱՑԱՀ", "ԲԱՑՎԵ", "ԲԲԵՐԻ",
        "ԲԵՄԵՐ", "ԲԵՌՆԱ", "ԲԵՌՆԵ", "ԲԵՐԴԻ", "ԲԵՐՔԻ", "ԲԺԻՇԿ", "ԲՆԱԿԱ", "ԲՆԱԿԻ", "ԲՈՎԱՆ", "ԳԱԶԱՅ",
        "ԳԱՀԻՆ", "ԳԱՂԹԻ", "ԳԱՅԼԻ", "ԳԱՆՁԻ", "ԳԱՎԱԹ", "ԳԱՎԱՌ", "ԳԱՐԻՆ", "ԳԱՐՈՒՆ", "ԳԵՏԱԿ", "ԳԵՐԵԶ",
        "ԳԵՐԻՆ", "ԳԻՆԻՆ", "ԳԻՇԵՐ", "ԳԻՏԱԿ", "ԳՈՎԱԶ", "ԳՈՎԵԼ", "ԳՈՎԵՍ", "ԳՈՐԾԱ", "ԳՈՐԾԻ", "ԳՈՒՅՆՍ",
        "ԳՐԱԿԱ", "ԳՐԱՆՑ", "ԳՐԱՍԵ", "ԳՐՔԵՐ", "ԴԱՆԱԿ", "ԴԱՇՏԻ", "ԴԱՍԱԿ", "ԴԱՍԱՌ", "ԴԱՍԻՆ", "ԴԱՎԵՐ",
        "ԴԱՏԱՐ", "ԴԱՐԲԻ", "ԴԱՐԻՆ", "ԴԵՂԻՆ", "ԴԵՄՔԻ", "ԴԵՏԱԼ", "ԴԻԱԿԻ", "ԴԻՎԱՆ", "ԴԻՏԵԼ", "ԴՊՐՈՑ",
        "ԴՐԱՄԻ", "ԴՐՈՇՄ", "ԵԼՔԵՐ", "ԵՂՋԵՐ", "ԵՐԱԶՍ", "ԵՐԱԺՇ", "ԵՐԱՆԻ", "ԵՐԱՇՏ", "ԵՐԳԵԼ", "ԵՐԵԽԱ",
        "ԵՐԵՎԱ", "ԵՐԵՔՍ", "ԵՐԻՏԱ", "ԵՐԿԱԹ", "ԵՐԿԱՐ", "ԵՐԿԻՆ", "ԵՐԿԻՐ", "ԵՐԿՐԱ", "ԵՐԿՐՈ", "ԶԱՆԳԱ",
        "ԶԱՆԳԻ", "ԶԱՎԱԿ", "ԶԱՐԴԻ", "ԶԳԱԼԻ", "ԶԳԱՑՄ", "ԶԵՆՔԵ", "ԶԵՓՅՈՒ", "ԶԻՆՎՈ", "ԶՈՀԵՐ", "ԶՈՐՔԻ",
        "ԷԼԵԿՏ", "ԷՈՒԹՅՈՒ", "ԷՊՈՍԻ", "ԷՋԵՐԻ", "ԷՋԵՐՆ", "ԹԱՆԳԱ", "ԹԱՌԱՄ", "ԹԱՏԵՐ", "ԹԱՏՐՈ", "ԹԱՔՆՎ",
        "ԹԵԼԵՐ", "ԹԵՄԱՅ", "ԹԵՅԻՆ", "ԹԵՎԵՐ", "ԹԻՌՉԵ", "ԺԱՄԱՆ", "ԺԱՄԱՑ", "ԺԱՄԵՐ", "ԺԱՅՌԻ", "ԺՈՂՈՎ",
        "ԻՄԱՍՏ", "ԻՆՏԵՐ", "ԻՆՔՆԱ", "ԻՇԽԱՆ", "ԻՍԿԱԿ", "ԻՍՊԱՆ", "ԻՐԱԿԱ", "ԻՐԱՎԱ", "ԻՐԱՎՈ", "ԼԱՄՊԻ",
        "ԼԵԳԵՆ", "ԼԵԶՎԻ", "ԼԵՌԱՆ", "ԼԻԱԿԱ", "ԼՃԱԿԻ", "ԼՈՒՅՍԻ", "ԼՈՒՍԱՆ", "ԼՈՒՍԱՎ", "ԼՈՒՍԻՆ", "ԼՈՒՐԵՐ",
        "ԽԱՂԱՂ", "ԽԱՂԵՐ", "ԽԱՉԵԼ", "ԽԱՉԻՆ", "ԽԱՉՔԱ", "ԽԱՎԱՐ", "ԽԵԼԱՑ", "ԽԻԶԱԽ", "ԽՈՀԱՆ", "ԽՈՍԵԼ",
        "ԽՈՍՔԻ", "ԽՈՐՀՈ", "ԾԱԽՍԻ", "ԾԱՂԻԿ", "ԾԱՆՈԹ", "ԾԱՌԻՆ", "ԾԱՎԱԼ", "ԾԱՐԱՎ", "ԾՈՎԱԿ", "ԾՈՎԱՅ",
        "ԾՈՎԻՆ", "ԿԱԹԻԼ", "ԿԱՂՆԻ", "ԿԱՅԱՐ", "ԿԱՅՍՐ", "ԿԱՅՔԻ", "ԿԱՆՈՆ", "ԿԱՍԿԱ", "ԿԱՐԾԻ", "ԿԱՐՄԻ",
        "ԿԵԱՆՔ", "ԿԵՆԴԱ", "ԿԵՆՏՐ", "ԿԻՆՈՆ", "ԿԻՍԱՏ", "ԿԼԻՄԱ", "ԿՈՉԵԼ", "ԿՐԱԿԻ", "ՀԱՂՈՐ", "ՀԱՄԱԽ",
        "ՀԱՄԱՐ", "ՀԱՅԵԼ", "ՀԱՅՏՆ", "ՀԱՅՐԵ", "ՀԱՆԳԻ", "ՀԱՇՎԵ", "ՀԱՇՎԻ", "ՀԱՊԱՎ", "ՀԱՍԱԿ", "ՀԱՍԱՐ",
        "ՀԱՍՆԵ", "ՀԱՎԱՏ", "ՀԱՎԱՔ", "ՀԱՐՑԻ", "ՀԱՑԻԿ", "ՀԻՄՔԻ", "ՀԻՇԵԼ", "ՀԻՎԱՆ", "ՀՅՈՒՍԻ", "ՀՈՂԱՅ",
        "ՀՈՂՄԻ", "ՀՈՐԻԶ", "ՀՐԱՊԱ", "ՀՐԱՎԵ", "ՁԱՅՆԻ", "ՁԵՌՔԻ", "ՁԵՎԱԿ", "ՁԵՎԵՐ", "ՁՈՐԱԿ", "ՃԱԿԱՏ",
        "ՃԱՆԱՉ", "ՃԱՆԱՊ", "ՃԱՐՏԱ", "ՃՇՄԱՐ", "ՄԱԳԱՂ", "ՄԱԿԱՐ", "ՄԱՅՐԻ", "ՄԱՍԻՆ", "ՄԱՍՆԱ", "ՄԱՐԳԱ",
        "ՄԱՐԴԿ", "ՄԱՔՐՈ", "ՄԵԾԱՏ", "ՄԵԾԱՑ", "ՄԵՔԵՆ", "ՄԻԱՅՆ", "ՄԻՋՈՑ", "ՄԻՏՔՆ", "ՄՆԱՑԱ", "ՄՇԱԿՈ",
        "ՄՈԴԵԼ", "ՄՈՄԵՐ", "ՄՏՆԵԼ", "ՄՏՔԵՐ", "ՅՈՒՂՈՏ", "ՅՈՒՐԱՀ", "ՅՈՒՐԱՔ", "ՅՈՒՐՈՎ", "ՆԱԽԱԳ", "ՆԱԽԱՐ",
        "ՆԱԽԿԻ", "ՆԱՄԱԿ", "ՆԱՅԵԼ", "ՆԱՎԱԿ", "ՆԱՎԱՏ", "ՆԱՐԻՆ", "ՆԵՐԿԱ", "ՆԵՐՔԻ", "ՆԿԱՏԵ", "ՆԿԱՐԱ",
        "ՆԿԱՐԻ", "ՆՆՋԱՐ", "ՆՇԱՆԱ", "ՆՇԱՆԻ", "ՆՈՐՈԳ", "ՆՊԱՏԱ", "ՆՎԱՃՈ", "ՆՎԵՐԻ", "ՇԱԲԱԹ", "ՇԱՐԺՈ",
        "ՇԵՆՔԻ", "ՇԵՖԻՆ", "ՇԻՆԱՐ", "ՇՈՂԵՐ", "ՈՍԿԵԳ", "ՈՍԿԻՆ", "ՈՍՏԻԿ", "ՈՐՈՇՈ", "ՈՐՍՈՐ", "ՉԱՓԱԶ",
        "ՊԱՀԵԼ", "ՊԱՅՄԱ", "ՊԱՅՔԱ", "ՊԱՆԻՐ", "ՊԱՇՏՊ", "ՊԱՏԱՍ", "ՊԱՏԵՐ", "ՊԱՏԿԵ", "ՊԱՏՄՈ", "ՊԱՏՎԵ",
        "ՊԱՏՐԱ", "ՊԱՏՐԻ", "ՊԱՐԵԼ", "ՊԱՐԶԱ", "ՊԵՏԱԿ", "ՊԻՏԻՆ", "ՊՈՏԵՆ", "ՊՐՈՖԵ", "ՋԱՆՔԻ", "ՋԵՐՄԱ",
        "ՋԵՐՄՈ", "ՌԱԲԲԻ", "ՌԱԴԻՈ", "ՌԱԶՄԻ", "ՌԵԱԼԻ", "ՌԵԱԿՑ", "ՍԱՀՄԱ", "ՍԱՌԸՆ", "ՍԱՐԵՐ", "ՍԵՂԱՆ",
        "ՍԵՆՅԱ", "ՍԵՎԱԿ", "ՍԻՐԱՀ", "ՍԻՐՈՅ", "ՍԻՐՏՆ", "ՍԿԻԶԲ", "ՍԿՍԵԼ", "ՍՈՎՈՐ", "ՍՊԱՍԵ", "ՍՊԻՏԱ",
        "ՍՊՈՐՏ", "ՍՏԵՂԾ", "ՍՐԲԱԶ", "ՍՐՏԻՆ", "ՎԱԳՈՆ", "ՎԱԳՐՍ", "ՎԱՃԱՌ", "ՎԱՆՔԻ", "ՎԱՍՏԱ", "ՎԱՏԹԱ",
        "ՎԱՐԴԻ", "ՎԵՐԱԲ", "ՎԵՐՋԻ", "ՎԻՃԱԿ", "ՎԻՐԱՎ", "ՏԱՂԱՆ", "ՏԱՆՋԱ", "ՏԱՐԱԾ", "ՏԱՐԲԵ", "ՏԱՐԻՆ",
        "ՏԱՓԱԿ", "ՏԵՂԵԿ", "ՏԵՂԻՆ", "ՏԵՍԱԿ", "ՏԵՍՆԵ", "ՏԵՏՐԻ", "ՏԻՊԻՆ", "ՏՈԿՈՍ", "ՏՈՆԵՐ", "ՏՐԱՄԱ",
        "ՐԱՊՈՏ", "ՑԱՆԿԱ", "ՑԱՎՈՔ", "ՑՈՐԵՆ", "ՓԱԿԵԼ", "ՓԱԿՎԵ", "ՓԱՅՏԻ", "ՓԱՍՏԻ", "ՓՈԽԱՐ", "ՓՈՂՈՑ",
        "ՓՈՏՈՐ", "ՓՈՐՁԻ", "ՔԱՂԱՔ", "ՔԱՄԻՆ", "ՔԱՅԼԻ", "ՔԱՆԱԿ", "ՔԱՐԵՐ", "ՔԱՐՏԵ", "ՔԻՄԻԱ", "ՔՐԻՍՏ",
        "ՕԳՆԵԼ", "ՕԳՏԱԳ", "ՕԳՏԱԿ", "ՕԴԱՅԻ", "ՕՐԵՆՔ", "ՕՐԻՆԱ", "ՖԱԲՐԻ", "ՖԱՅԼԻ", "ՖԻԼՄԻ", "ՖԻՆԱՆ"
    ]

    // MARK: - Lookup sets

    static let englishSet: Set<String> = Set(english.map { $0.uppercased() })
    static let armenianSet: Set<String> = Set(armenian.map { $0.uppercased() })
    // The list actually used for Armenian play (tokenised to 5 letters, ու = 1)
    // lives in `GameLanguage.armenianPlayableWords`.
}