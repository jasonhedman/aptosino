/// https://math.hawaii.edu/~ramsey/Probability/PokerHands.html
/// Allow people to bet on the above categories in a 5 card hand of poker.
/// Kind of a specification of roulette.
/// Number of possible hands: 2,598,960
/// Intuitively exclusive categories (i.e. a hand can't be both a single pair and a triple)
/// Single Pair (1): 1098240
/// Two Pair (2): 123552
/// Triple (3): 54912
/// Full House (4): 3744
/// Four of a Kind (5): 624
/// Intuitively non-exclusive categories:
/// Straight (6): 10240
/// Flush (7): 5144
/// Straight Flush (8): 40
/// Royal Flush (9): 4
/// None (0): 1302540
/// 10 possible categories - odds baked into the game

module aptosino::poker {

    use std::signer;
    use std::vector;

    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::game;

    use aptosino::house;


    /// The number of bets does not match the number of predicted outcomes
    const ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes: u64 = 101;
    /// The number of bets is zero
    const ENumberOfBetsIsZero: u64 = 102;
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 103;
    /// The number of predicted outcomes is zero for a bet
    const EInvalidNumberOfPredictedOutcomes: u64 = 104;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 105;
    /// A predicted outcome is invalid

    const NUM_OUTCOMES: u64 = 2598960;

    // Structs

    struct FiveCardDrawPoker has drop {}

    /// A deck is a vector of cards (in this module we force a standard deck of 52 cards)
    struct Card has copy, drop{
        suit: u8,
        rank: u8,
    }

    // events

    #[event]
    /// Event emitted when the dice are rolled
    struct DealCardsEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount of each bet
        bet_amounts: vector<u64>,
        /// The hands the player bet on
        predicted_outcomes: vector<u8>,
        /// Dealt cards
        cards_dealt: vector<Card>,
        /// Winning hands
        result: vector<u8>,
    }

    // game functions

    /// Deals the cards and pays out the player according to his bet
    public entry fun deal_cards(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<u8>
    ) {
        let deck = build_deck();

        let shuffle = randomness::permutation(52);
        let cards_dealt: vector<Card> = vector::empty<Card>();
        while (vector::length(cards_dealt) < 5) {
            let card = vector::borrow<Card>(&deck, vector::borrow<u64>(&shuffle, cards_dealt));
            vector::push_back<Card>(cards_dealt, card);
        };

        let result = get_dealt_hands_from_cards(cards_dealt);

        /// If no hands are found, we add the field to the result
        if (vector::length(result) == 0) {
            vector::push_back<u8>(result, 0);
        };

        deal_cards_impl(player, bet_amount_inputs, predicted_outcomes, cards_dealt, result);
    }

    /// Implementation of the deal_cards function
    /// * result: the hands which were dealt
    fun deal_cards_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u8>,
        cards_dealt: vector<Card>,
        result: vector<u8>
    ) {
        assert_bets_are_valid(&bet_amounts, &predicted_outcomes);

        let total_bet_amount = 0;
        vector::for_each(bet_amounts, |amount| {
            total_bet_amount = total_bet_amount + amount;
        });

        let game = game::create_game(player, total_bet_amount, FiveCardDrawPoker {});

        let payout_numerator = 0;
        let payout_denominator = 0;

        let i = 0;
        while (i < vector::length(&bet_amounts)) {
            let predicted_outcome = vector::borrow(&predicted_outcomes, i);
            assert_predicted_outcome_is_valid(predicted_outcome);
            if(vector::contains(predicted_outcome, &result)) {
                let category_size = get_category_size(predicted_outcome);
                payout_numerator = payout_numerator + (NUM_OUTCOMES as u64) * *vector::borrow(&bet_amounts, i);
                payout_denominator = payout_denominator + category_size * total_bet_amount;
            };
            i = i + 1;
        };

        game::resolve_game(
            game,
            payout_numerator,
            if(payout_denominator > 0) { payout_denominator } else { 1 },
            FiveCardDrawPoker {}
        );

        event::emit(DealCardsEvent {
            player_address: signer::address_of(player),
            bet_amounts,
            predicted_outcomes,
            cards_dealt,
            result,
        });
    }

    /// Identify hands in the dealt cards and return a vector containing all the hands, empty if none
    fun get_dealt_hands_from_cards(cards: vector<Card>): vector<u8> {
        let flush = false;

        let hands = vector::empty<u8>();

        let unique_ranks_found = vector::empty<u8>();
        let unique_suits_found = vector::empty<u8>();

        vector::for_each(cards, |card| {
            if (!vector::contains(unique_ranks_found, card.rank)) {
                vector::push_back<u8>(unique_ranks_found, card.rank);
            };
            if (!vector::contains(unique_suits_found, card.suit)) {
                vector::push_back<u8>(unique_suits_found, card.suit);
            };
        });

        /// If we only find 1 suit, we have a flush, we mark it here to handle straight flushes later
        if (vector::length(unique_suits_found) == 1) {
            vector::push_back<u8>(hands, 7);
            flush = true;
        };

        /// Unles we have 5 unique ranks, we can't have a straight
        if (vector::length(unique_ranks_found) == 5) {
            if (check_straight(unique_ranks_found)) {
                /// Straight
                vector::push_back<u64>(hands, 6);
                /// Straight flush
                if (flush) {
                    vector::push_back<u64>(hands, 8);
                    /// Royal flush
                    if (get_highest_rank(unique_ranks_found) == 14 ) {
                        vector::push_back<u64>(hands, 9);
                    };
                };
            };
        };

        /// If we have 4 unique ranks, we have a single pair
        if (vector::length(unique_ranks_found) == 4) {
            /// Single pair
            vector::push_back<u64>(hands, 1);
        };

        /// If we have 3 unique ranks, we have a triple or two pair
        if (vector::length(unique_ranks_found) == 3) {
            if (check_triple(unique_ranks_found)) {
                /// Triple
                vector::push_back<u64>(hands, 3);
            } else {
                /// Two pair
                vector::push_back<u64>(hands, 2);
            };
        };

        /// If we have 2 unique ranks, we have a full house or four of a kind
        if (vector::length(unique_ranks_found) == 2) {
            if (check_four_of_a_kind(unique_ranks_found)) {
                /// Four of a kind
                vector::push_back<u64>(hands, 5);
            } else {
                /// Full house
                vector::push_back<u64>(hands, 4);
            };
        };

        hands
    }

    fun check_triple(ranks_found: vector<u64>): bool {
        let triple = false;
        vector::for_each(ranks_found, |rank| {
            let count = 0;
            vector::for_each(cards, |card| {
                if (card.rank == rank) {
                    count = count + 1;
                };
            });
            if (count == 3) {
                triple = true;
            };
        });
        triple
    }

    fun check_four_of_a_kind(ranks_found: vector<u64>): bool {
        let four_of_a_kind = false;
        vector::for_each(ranks_found, |rank| {
            let count = 0;
            vector::for_each(cards, |card| {
                if (card.rank == rank) {
                    count = count + 1;
                };
            });
            if (count == 4) {
                four_of_a_kind = true;
            };
        });
        four_of_a_kind
    }

    /// Check if the cards form a straight, ranks are guranteed to be unique
    /// Aces can be high (14) or low(1), they are represented as 1 in the cards
    fun check_straight(ranks_found: &vector<u64>): bool {
        let ranks = vector::empty<u64>();
        let high_ace = false;

        /// If we have a king, we will treat any aces as high
        vector::for_each(ranks_found, |rank| {
            if (rank == 13) {
                high_ace = true;
            }
        });

        vector::for_each(cards, |card| {
            if (card.rank == 1 && high_ace) {
                vector::push_back<u64>(ranks, 14);
            } else {
                vector::push_back<u64>(ranks, card.rank);
            };
        });

        vector::all(ranks, |rank| {
            vector::contains(ranks, rank + 1) || vector::contains(ranks, rank - 1)
        })
    }

    /// Return the highest rank in the hand
    fun get_highest_rank(cards: vector<Card>): u64 {
        let max_rank = 0;
        vector::for_each(cards, |card| {
            if (card.rank > max_rank) {
                max_rank = card.rank;
            };
        });
        max_rank
    }

    // utility functions

    /// Builds a standard deck of 52 cards and returns
    fun build_deck(): vector<Card> {
        let suit = 0;
        let rank = 1;
        let deck = vector::empty<Card>();
        while (suit < 4) {
            while (rank < 14) {
                vector::push_back<Card>(deck, Card {suit, rank});
                rank = rank + 1;
            };
            rank = 1;
            suit = suit + 1;
        };
        deck
    }

    // getters

    fun get_category_size(predicted_outcome: u8): u64 {
        assert!(predicted_outcome < 9 && predicted_outcome > 0, EPredictedOutcomeOutOfRange);
        /// Represents a bet on no hands (the field)
        if (predicted_outcome == 0) {
            1302540
        };
        /// Represents bet on a single pair
        if (predicted_outcome == 1) {
            1098240
        };
        /// Represents bet on two pairs
        if (predicted_outcome == 2) {
            123552
        };
        /// Represents bet on a triple
        if (predicted_outcome == 3) {
            54912
        };
        /// Represents bet on a full house
        if (predicted_outcome == 4) {
            3744
        };
        /// Represents bet on a four of a kind
        if (predicted_outcome == 5) {
            624
        };
        /// Represents bet on a straight
        if (predicted_outcome == 6) {
            10240
        };
        /// Represents bet on a flush
        if (predicted_outcome == 7) {
            5144
        };
        /// Represents bet on a straight flush
        if (predicted_outcome == 8) {
            40
        };
        /// Represents bet on a royal flush
        if (predicted_outcome == 9) {
            4
        } else {
            0
        }
    }

    #[view]
    /// Returns the multiplier for a given bet
    /// * predicted_outcome: the hand the player predicted, represented as a number
    /// Returns: the multiplier for the bet as a vector, where the first element
    /// is the numerator and the second element is the denominator
    public fun get_bet_multiplier(predicted_outcome: u64): vector<u64> {
        assert!(predicted_outcome < 9 && predicted_outcome > 0, EPredictedOutcomeOutOfRange);
        let multiplier_numerator = 2598960;
        let multiplier_denominator: u64;
        /// Represents a bet on no hands (the field)
        if (predicted_outcome == 0) {
            multiplier_denominator = 1302540;
        };
        /// Represents bet on a single pair
        if (predicted_outcome == 1) {
            multiplier_denominator = 1098240;
        };
        /// Represents bet on two pairs
        if (predicted_outcome == 2) {
            multiplier_denominator = 123552;
        };
        /// Represents bet on a triple
        if (predicted_outcome == 3) {
            multiplier_denominator = 54912;
        };
        /// Represents bet on a full house
        if (predicted_outcome == 4) {
            multiplier_denominator = 3744;
        };
        /// Represents bet on a four of a kind
        if (predicted_outcome == 5) {
            multiplier_denominator = 624;
        };
        /// Represents bet on a straight
        if (predicted_outcome == 6) {
            multiplier_denominator = 10240;
        };
        /// Represents bet on a flush
        if (predicted_outcome == 7) {
            multiplier_denominator = 5144;
        };
        /// Represents bet on a straight flush
        if (predicted_outcome == 8) {
            multiplier_denominator = 40;
        };
        /// Represents bet on a royal flush
        if (predicted_outcome == 9) {
            multiplier_denominator = 4;
        };
        let bet_multiplier = vector::empty<u64>();
        vector::push_back<u64>(bet_multiplier, multiplier_numerator);
        vector::push_back<u64>(bet_multiplier, multiplier_denominator);
        bet_multiplier
    }


    // assert statements

    /// Checks that the predicted outcome is valid (i.e. in the range 1-9)
    fun assert_predicted_outcome_is_valid(predicted_outcome: u8) {
        assert!(predicted_outcome >= 0 && predicted_outcome <= 9, EPredictedOutcomeOutOfRange
    }

    /// Checks that the bets are valid
    fun assert_bets_are_valid(bet_amounts: &vector<u64>, predicted_outcomes: &vector<u8>) {
        assert!(vector::length(bet_amounts) == vector::length(predicted_outcomes),
            ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes);
        assert!(vector::length(bet_amounts) > 0, ENumberOfBetsIsZero);
        assert!(vector::all(bet_amounts, |amount| { *amount > 0 }), EBetAmountIsZero);
    }



    // test functions

    #[test_only]
    public fun test_deal_cards(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u8>,
        cards_dealt: vector<Card>,
        result: vector<u8>
    ) {
       deal_cards_impl(player, bet_amounts, predicted_outcomes, cards_dealt, result);
    }
}