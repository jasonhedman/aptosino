#[test_only]
module aptosino::test_poker {
    use std::signer;
    use std::vector;

    use aptosino::poker;
    use aptosino::poker::Card;
    use aptosino::poker::newCard;

    const INITIAL_DEPOSIT: u64 = 1_000_000_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 20;
    const FEE_BPS: u64 = 100;
    const FEE_DIVISOR: u64 = 10_000;
    const BET_AMOUNT: u64 = 1_000_000;

    const HIGHCARD: u8 = 0;
    const ONEPAIR: u8 = 1;
    const TWOPAIR: u8 = 2;
    const THREEOFAKIND: u8 = 3;
    const FULLHOUSE: u8 = 6;
    const FOUROFAKIND: u8 = 7;
    const STRAIGHT: u8 = 4;
    const FLUSH: u8 = 5;
    const STRAIGHTFLUSH: u8 = 8;
    const ROYALFLUSH: u8 = 9;

    fun get_highcard(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 0);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(4, 1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(6, 0);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(10, 0);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(11, 0);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_pair(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one =  newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two =  newCard(2, 1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(3, 2);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(4, 2);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(5, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_twopair(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(2, 2);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(3, 2);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(3, 1);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(5, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_threeofakind(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(2, 2);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(2, 0);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(3, 2);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(4, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_fourofakind(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(2, 2);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(2, 0);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(2, 2);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(4, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_fullhouse(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(2, 2 );
        vector::push_back(&mut hand, card_two);
        let card_three = newCard( 2, 2);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(3,  1);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(3, 1);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_straight(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(3, 2);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(4, 3);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(5, 0);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(6, 0);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_straight_ace_low(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(1, 0);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(2, 1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(3, 0);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(4, 1);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(5, 0);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_straight_ace_high(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(1, 1);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(10, 1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(11, 1);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(12, 1);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(13, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_flush(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2, 2);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(3, 2);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(6, 2);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(5, 2);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard(10, 2);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_straightflush(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(2,1);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(3,1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(4,1);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard(5,1);
        vector::push_back(&mut hand, card_four);
        let card_five =  newCard(6,1);
        vector::push_back(&mut hand, card_five);
        hand
    }

    fun get_royalflush(): vector<Card> {
        let hand = vector::empty<Card>();
        let card_one = newCard(10, 1);
        vector::push_back(&mut hand, card_one);
        let card_two = newCard(11, 1);
        vector::push_back(&mut hand, card_two);
        let card_three = newCard(12, 1);
        vector::push_back(&mut hand, card_three);
        let card_four = newCard (13,1);
        vector::push_back(&mut hand, card_four);
        let card_five = newCard (1, 1);
        vector::push_back(&mut hand, card_five);
        hand
    }


    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun get_dealt_hands_from_cards_test() {

        // Highcard, no flush
        let cards = get_highcard();
        let hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &HIGHCARD), 0);
        assert!(vector::length(hands) == 1, 0);

        // Flush
        cards = get_flush();
        let hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &FLUSH), 0);
        assert!(vector::length(hands) == 1, 0);

        // Pair
        cards = get_pair();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &ONEPAIR), 0);
        assert!(vector::length<u8>(hands) == 1, 0);

        // Two pair
        cards = get_twopair();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &TWOPAIR), 0);
        assert!(vector::length(hands) == 1, 0);

        // Three of a kind
        cards = get_threeofakind();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &THREEOFAKIND), 0);
        assert!(vector::length(hands) == 1, 0);

        // Full house
        cards = get_fullhouse();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &FULLHOUSE), 0);
        assert!(vector::length(hands) == 1, 0);

        // Four of a kind
        cards = get_fourofakind();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &FOUROFAKIND), 0);
        assert!(vector::length(hands) == 1, 0);

        // Straight
        cards = get_straight();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &STRAIGHT), 0);
        assert!(vector::length(hands) == 1, 0);

        // Straight, ace low
        cards = get_straight_ace_low();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &STRAIGHT), 0);
        assert!(vector::length(hands) == 1, 0);

        // Straight, ace high
        cards = get_straight_ace_high();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &STRAIGHT), 0);
        assert!(vector::length(hands) == 1, 0);

        // Straight flush
        cards = get_straightflush();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &FLUSH), 0);
        assert!(vector::contains<u8>(hands, &STRAIGHT), 0);
        assert!(vector::contains<u8>(hands, &STRAIGHTFLUSH), 0);
        assert!(vector::length(hands) == 3, 0);

        // Royal flush
        cards = get_royalflush();
        hands = &poker::get_dealt_hands_from_cards(cards);
        assert!(vector::contains<u8>(hands, &FLUSH), 0);
        assert!(vector::contains<u8>(hands, &STRAIGHT), 0);
        assert!(vector::contains<u8>(hands, &STRAIGHTFLUSH), 0);
        assert!(vector::contains<u8>(hands, &ROYALFLUSH), 0);
        assert!(vector::length<u8>(hands) == 4, 0);
    }
}