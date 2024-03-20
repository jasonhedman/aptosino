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
        if (winning_hand == HIGHCARD) {
            result = get_highcard();
        } else if (winning_hand == ONEPAIR) {
            result = get_pair();
        } else if (winning_hand == TWOPAIR) {
            result = get_twopair();
        } else if (winning_hand == THREEOFAKIND) {
            result = get_threeofakind();
        } else if (winning_hand == FULLHOUSE) {
            result = get_fullhouse();
        } else if (winning_hand == FOUROFAKIND) {
            result = get_fourofakind();
        } else if (winning_hand == STRAIGHT) {
            result = get_straight();
        } else if (winning_hand == FLUSH) {
            result = get_flush();
        } else if (winning_hand == STRAIGHTFLUSH) {
            result = get_straightflush();
        } else if (winning_hand == ROYALFLUSH) {
            result = get_royalflush();
        } else {
            assert!(false, 0);
        };

        poker::test_deal_cards(
            player,
            bet_amounts,
            predicted_outcomes,
            winning_hand,
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
    fun deal_split_win_lose(framework: &signer, aptosino: &signer, player: &signer) {
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

        let bet_amounts: vector<u64> = vector[BET_AMOUNT, BET_AMOUNT];
        let predicted_outcomes: vector<u8> = vector[HIGHCARD, ONEPAIR];
        let (house_balance_change, user_balance_change) = deal_test(
            player,
            bet_amounts,
            predicted_outcomes,
            ONEPAIR,
        );

        let payout = poker::get_payout(BET_AMOUNT, ONEPAIR);
        // NOTE: The payout already includes the fee for the winning portion of the hand, we double
        // it to account for the losing portion of the hand. May not be expected behavior.
        assert!(house_balance_change == payout - BET_AMOUNT * 2 - house::get_fee_amount(BET_AMOUNT), 0);
        assert!(user_balance_change == payout - BET_AMOUNT * 2 - house::get_fee_amount(BET_AMOUNT), 0);
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
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == HIGHCARD, 0);

        // One pair
        let cards = get_pair();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == ONEPAIR, 0);

        // Two pair
        let cards = get_twopair();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == TWOPAIR, 0);

        // Three of a kind
        let cards = get_threeofakind();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == THREEOFAKIND, 0);

        // Full house
        let cards = get_fullhouse();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == FULLHOUSE, 0);

        // Four of a kind
        let cards = get_fourofakind();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == FOUROFAKIND, 0);

        // Straight
        let cards = get_straight();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == STRAIGHT, 0);

        // Flush
        let cards = get_flush();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == FLUSH, 0);

        // Straight flush
        let cards = get_straightflush();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == STRAIGHTFLUSH, 0);

        // Royal flush
        let cards = get_royalflush();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == ROYALFLUSH, 0);

        // Straight, ace low
        let cards = get_straight_ace_low();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == STRAIGHT, 0);

        // Straight, ace high
        let cards = get_straight_ace_high();
        let hand = poker::get_winning_hand_from_cards(cards);
        assert!(hand == STRAIGHT, 0);

    }

    #[test(framework = @aptos_framework, aptosino = @aptosino, player = @0x101)]
    #[expected_failure(abort_code= poker::ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes)]
    fun test_deal_cards_num_predictions_not_num_bets(framework: &signer, aptosino: &signer, player: &signer) {
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
    fun test_deal_cards_bet_amount_empty(framework: &signer, aptosino: &signer, player: &signer) {
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
    fun test_deal_cards_bet_amount_zero(framework: &signer, aptosino: &signer, player: &signer) {
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
    fun test_deal_cards_empty_predictions(framework: &signer, aptosino: &signer, player: &signer) {
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
    fun test_deal_cards_invalid_prediction(framework: &signer, aptosino: &signer, player: &signer) {
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