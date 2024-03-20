#[test_only]
module aptosino::test_poker {
    use std::signer;
    use std::vector;

    use aptos_framework::coin;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptosino::house;

    use aptosino::poker;
    use aptosino::poker::Card;
    use aptosino::test_helpers;

    use aptosino::poker::newCard;

    const INITIAL_DEPOSIT: u64 = 1_000_000_000_000;
    const MIN_BET: u64 = 1_000_000;
    const MAX_BET: u64 = 10_000_000;
    const MAX_MULTIPLIER: u64 = 3_000_000;
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

    // The number of possible outcomes in a five-card-draw poker hand
    const NUM_OUTCOMES: u64 = 2598960;

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

    fun deal_test(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u8>,
        winning_hand: u8
    ): (u64, u64) {
        let house_balance = house::get_house_balance();
        let user_balance = coin::balance<AptosCoin>(signer::address_of(player));

        let result: vector<Card> = vector::empty<Card>();
        let winning_hands: vector<u8> = vector::empty<u8>();
        if (winning_hand == HIGHCARD) {
            result = get_highcard();
            winning_hands = vector[HIGHCARD];
        } else if (winning_hand == ONEPAIR) {
            result = get_pair();
            winning_hands = vector[ONEPAIR];
        } else if (winning_hand == TWOPAIR) {
            result = get_twopair();
            winning_hands = vector[TWOPAIR];
        } else if (winning_hand == THREEOFAKIND) {
            result = get_threeofakind();
            winning_hands = vector[THREEOFAKIND];
        } else if (winning_hand == FULLHOUSE) {
            result = get_fullhouse();
            winning_hands = vector[FULLHOUSE];
        } else if (winning_hand == FOUROFAKIND) {
            result = get_fourofakind();
            winning_hands = vector[FOUROFAKIND];
        } else if (winning_hand == STRAIGHT) {
            result = get_straight();
            winning_hands = vector[STRAIGHT];
        } else if (winning_hand == FLUSH) {
            result = get_flush();
            winning_hands = vector[FLUSH];
        } else if (winning_hand == STRAIGHTFLUSH) {
            result = get_straightflush();
            winning_hands = vector[FLUSH, STRAIGHT, STRAIGHTFLUSH];
        } else if (winning_hand == ROYALFLUSH) {
            result = get_royalflush();
            winning_hands = vector[FLUSH, STRAIGHT, STRAIGHTFLUSH, ROYALFLUSH];
        } else {
            assert!(false, 0);
        };

        poker::test_deal_cards(
            player,
            bet_amounts,
            predicted_outcomes,
            winning_hands,
            result,
        );

        let new_house_balance = house::get_house_balance();
        let new_user_balance = coin::balance<AptosCoin>(signer::address_of(player));

        if(new_house_balance < house_balance) {
            return (house_balance - new_house_balance, new_user_balance - user_balance)
        } else {
            return (new_house_balance - house_balance, user_balance - new_user_balance)
        }
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_deal_one_bet_win(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        let bet_amounts: vector<u64> = vector[BET_AMOUNT];
        let predicted_outcome = HIGHCARD;
        while (predicted_outcome <= ROYALFLUSH) {
            let (house_balance_change, user_balance_change) = deal_test(
                player,
                bet_amounts,
                vector[predicted_outcome],
                predicted_outcome,
            );
            let payout = poker::get_payout(BET_AMOUNT, predicted_outcome);
            assert!(house_balance_change == payout - BET_AMOUNT, 0);
            assert!(user_balance_change == payout - BET_AMOUNT, 0);
            predicted_outcome = predicted_outcome + 1;
        }
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_deal_one_bet_lose(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        let bet_amounts: vector<u64> = vector[BET_AMOUNT];
        let predicted_outcome = HIGHCARD;
        while (predicted_outcome <= ROYALFLUSH) {
            if (predicted_outcome != HIGHCARD) {
                let (house_balance_change, user_balance_change) = deal_test(
                    player,
                    bet_amounts,
                    vector[predicted_outcome],
                    HIGHCARD,
                );
                assert!(house_balance_change == BET_AMOUNT, 0);
                assert!(user_balance_change == BET_AMOUNT, 0);
            } else {
                let (house_balance_change, user_balance_change) = deal_test(
                    player,
                    bet_amounts,
                    vector[predicted_outcome],
                    2
                );
                assert!(house_balance_change == BET_AMOUNT, 0);
                assert!(user_balance_change == BET_AMOUNT, 0);
            };
            predicted_outcome = predicted_outcome + 1;
        }
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_get_payout(framework: &signer, aptosino: &signer) {
        test_helpers::setup_house(
            framework,
            aptosino,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );
        let fee = test_helpers::get_fee(BET_AMOUNT, FEE_BPS, FEE_DIVISOR);

        let payout = poker::get_payout(BET_AMOUNT, HIGHCARD);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(HIGHCARD) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, ONEPAIR);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(ONEPAIR) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, TWOPAIR);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(TWOPAIR) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, THREEOFAKIND);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(THREEOFAKIND) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, FULLHOUSE);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(FULLHOUSE) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, FOUROFAKIND);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(FOUROFAKIND) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, STRAIGHT);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(STRAIGHT) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, FLUSH);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(FLUSH) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, STRAIGHTFLUSH);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(STRAIGHTFLUSH) - fee, 0);

        let payout = poker::get_payout(BET_AMOUNT, ROYALFLUSH);
        assert!(payout == BET_AMOUNT * NUM_OUTCOMES / poker::get_category_size(ROYALFLUSH) - fee, 0);
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    fun test_get_dealt_hands_from_cards() {

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

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes)]
    fun test_spin_wheel_num_predictions_not_num_bets(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        deal_test(
            player,
            vector[BET_AMOUNT, BET_AMOUNT],
            vector[HIGHCARD],
            HIGHCARD,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes)]
    fun test_spin_wheel_bet_amount_empty(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        deal_test(
            player,
            vector[],
            vector[HIGHCARD],
            HIGHCARD,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::EBetAmountIsZero)]
    fun test_spin_wheel_bet_amount_zero(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        deal_test(
            player,
            vector[0],
            vector[HIGHCARD],
            HIGHCARD,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes)]
    fun test_spin_wheel_empty_predictions(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        deal_test(
            player,
            vector[BET_AMOUNT],
            vector[],
            HIGHCARD,
        );
    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::EPredictedOutcomeOutOfRange)]
    fun test_spin_wheel_invalid_prediction(framework: &signer, aptosino: &signer, player: &signer) {
        test_helpers::setup_house_with_player(
            framework,
            aptosino,
            player,
            INITIAL_DEPOSIT,
            MIN_BET,
            MAX_BET,
            MAX_MULTIPLIER,
            FEE_BPS,
        );

        poker::approve_game(aptosino);

        deal_test(
            player,
            vector[BET_AMOUNT],
            vector[10],
            HIGHCARD,
        );
    }
}