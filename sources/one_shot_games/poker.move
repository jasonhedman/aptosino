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

    // For readability
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


    // Structs

    struct FiveCardDrawPoker has drop {}

    // A deck is a vector of cards (in this module we force a standard deck of 52 cards)
    struct Card has copy, drop, store {
        suit: u8,
        rank: u8,
    }

    // Builds a standard deck of 52 cards and returns a copy of it
    fun build_deck(): vector<Card> {
        let suit = 0;
        let rank = 1;
        let deck = vector::empty<Card>();
        let deck_mut = &mut deck;
        while (suit < 4) {
            while (rank < 14) {
                vector::push_back<Card>(deck_mut, Card { suit, rank });
                rank = rank + 1;
            };
            rank = 1;
            suit = suit + 1;
        };
        deck
    }

    // events

    #[event]
    /// Event emitted when the cards are dealt
    struct DealCardsEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount of each bet
        bet_amounts: vector<u64>,
        /// The hands the player bet on
        predicted_outcomes: vector<u8>,
        /// Dealt cards (rank, suit) where rank is a number between 1 and 13 and suit is a number between 0 and 3
        /// Length is 5
        cards_dealt: vector<Card>,
        /// Winning hands
        result: vector<u8>,
    }


    // admin functions

    /// Approves the dice game on the house module
    /// * admin: the signer of the admin account
    public entry fun approve_game(admin: &signer) {
        house::approve_game<FiveCardDrawPoker>(admin, FiveCardDrawPoker {});
    }


    /// Deals the cards and pays out the player according to his bet
    public entry fun deal_cards(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<u8>
    ) {
        let deck = build_deck();
        let shuffle: vector<u64> = randomness::permutation(52);
        let cards_dealt: vector<Card> = vector::empty<Card>();
        let dealer = &mut cards_dealt;

        let i: u64 = 0;
        while (i < 5) {
            let card = *vector::borrow<Card>(&deck, *vector::borrow<u64>(&shuffle, i));
            vector::push_back<Card>(dealer, card);
            i = i + 1;
        };

        let winning_hands = get_dealt_hands_from_cards(cards_dealt);

        deal_cards_impl(player, bet_amount_inputs, predicted_outcomes, winning_hands, cards_dealt);

    }

    fun deal_cards_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u8>,
        winning_hands: vector<u8>,
        cards_dealt: vector<Card>
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
            if(vector::contains(&winning_hands, predicted_outcome)) {
                payout_numerator = payout_numerator + NUM_OUTCOMES * *vector::borrow(&bet_amounts, i);
                payout_denominator = payout_denominator + get_category_size(*predicted_outcome) * total_bet_amount;
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
            result: winning_hands,
        });
    }


    fun get_dealt_hands_from_cards(cards: vector<Card>): vector<u8> {
        let flush = false;

        let hands = vector::empty<u8>();
        let hands_ref = &mut hands;

        let unique_ranks = vector::empty<u8>();
        let unique_ranks_ref = &mut unique_ranks;

        let unique_suits = vector::empty<u8>();
        let unique_suits_ref = &mut unique_suits;

        vector::for_each<Card>(cards, |card| {
            let card: Card = card;
            if (!vector::contains<u8>(unique_ranks_ref, &card.rank)) {
                vector::push_back<u8>(unique_ranks_ref, card.rank);
            };
            if (!vector::contains<u8>(unique_suits_ref, &card.suit)) {
                vector::push_back<u8>(unique_suits_ref, card.suit);
            };
        });

        // If we only find 1 suit, we have a flush, we mark it here to handle straight flushes later
        if (vector::length(unique_suits_ref) == 1) {
            vector::push_back<u8>(hands_ref, FLUSH);
            flush = true;
        };

        // Unless we have 5 unique ranks, we can't have a straight
        if (vector::length(unique_ranks_ref) == 5) {
            if (check_straight(unique_ranks_ref)) {
                vector::push_back<u8>(hands_ref, STRAIGHT);
                if (flush) {
                    vector::push_back<u8>(hands_ref, STRAIGHTFLUSH);
                    // Royal flush
                    if (vector::contains(unique_ranks_ref, &13) && vector::contains(unique_ranks_ref, &1)) {
                        vector::push_back<u8>(hands_ref, ROYALFLUSH);
                    }
                };
            };
        };

        // If we have 4 unique ranks, we have a pair
        if (vector::length(unique_ranks_ref) == 4) {
            vector::push_back<u8>(hands_ref, ONEPAIR);
        };

        // If we have 3 unique ranks, we have a triple or two pair
        if (vector::length(unique_ranks_ref) == 3) {
            if (check_triple(cards)) {
                // Triple
                vector::push_back<u8>(hands_ref, THREEOFAKIND);
            } else {
                // Two pair
                vector::push_back<u8>(hands_ref, TWOPAIR);
            };
        };


        // If we have 2 unique ranks, we have a full house or four of a kind
        if (vector::length(unique_ranks_ref) == 2) {
            if (check_four_of_a_kind(cards)) {
                // Four of a kind
                vector::push_back<u8>(hands_ref, FOUROFAKIND);
            } else {
                // Full house
                vector::push_back<u8>(hands_ref, FULLHOUSE);
            };
        };

        if (vector::length(hands_ref) == 0) {
            vector::push_back<u8>(hands_ref, HIGHCARD);
        };

        hands
    }

    fun check_four_of_a_kind(cards: vector<Card>): bool {
        let ranks = vector::empty<u8>();
        let ranks_ref = &mut ranks;

        let cards = cards;
        vector::for_each<Card>(cards, |card| {
            let card: Card = card;
            vector::push_back<u8>(ranks_ref, card.rank);
        });

        let count = 0;
        let i = 0;
        while (i < vector::length(ranks_ref)) {
            let j = 0;
            while (j < vector::length(ranks_ref)) {
                if (vector::borrow(ranks_ref, i) == vector::borrow(ranks_ref, j)) {
                    count = count + 1;
                };
                j = j + 1;
            };
            if (count == 4) {
                return true
            };
            count = 0;
            i = i + 1;
        };
        false
    }

    fun check_triple(cards: vector<Card>): bool {
        let ranks = vector::empty<u8>();
        let ranks_ref = &mut ranks;

        let cards = cards;
        vector::for_each<Card>(cards, |card| {
            let card: Card = card;
            vector::push_back<u8>(ranks_ref, card.rank);
        });

        let count = 0;
        let i = 0;
        while (i < vector::length(ranks_ref)) {
            let j = 0;
            while (j < vector::length(ranks_ref)) {
                if (vector::borrow(ranks_ref, i) == vector::borrow(ranks_ref, j)) {
                    count = count + 1;
                };
                j = j + 1;
            };
            if (count == 3) {
                return true
            };
            count = 0;
            i = i + 1;
        };
        false
    }


    fun check_straight(ranks: &vector<u8>): bool {
        let ranks = ranks;

        let high_card = 0;
        let low_card = 14;

        vector::for_each(*ranks, |rank| {
            if (rank == 13) {
                if (vector::contains<u8>(ranks, &1)) {
                    high_card = 14;
                }
            }
            else {
                if (rank > high_card) {
                    high_card = rank;
                };
                if (rank < low_card) {
                    low_card = rank;
                };
            }
        });
        high_card - low_card == 4
    }


    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * predicted_outcome: the numbers the player predicts
    public fun get_payout(bet_amount: u64, predicted_outcome: u8): u64 {
        let category_size = get_category_size(predicted_outcome);
        if (category_size == 0) {
            0
        } else {
            bet_amount * NUM_OUTCOMES / category_size
        }
    }

    /// Returns the size of the category for a given predicted outcome
    /// * predicted_outcome: the hand the player predicted, represented as a number
    /// Returns: the size of the category as a u64, or 0 if the predicted outcome is invalid
    fun get_category_size(predicted_outcome: u8): u64 {
        assert!(predicted_outcome <= 9 && predicted_outcome >= 0, EPredictedOutcomeOutOfRange);
        if (predicted_outcome == HIGHCARD) {
            1302540
        } else if (predicted_outcome == ONEPAIR) {
            1098240
        } else if (predicted_outcome == TWOPAIR) {
            123552
        } else if (predicted_outcome == THREEOFAKIND) {
            54912
        } else if (predicted_outcome == FULLHOUSE) {
            3744
        } else if (predicted_outcome == FOUROFAKIND) {
            624
        } else if (predicted_outcome == STRAIGHT) {
            10240
        } else if (predicted_outcome == FLUSH) {
            5144
        } else if (predicted_outcome == STRAIGHTFLUSH) {
            40
        } else if (predicted_outcome == ROYALFLUSH) {
            4
        } else {
            0
        }
    }

    /// Asserts that the number of bets and predicted outcomes are equal in length, non-empty, and non-zero
    /// * multiplier: the multiplier of the bet
    /// * bet_amounts: the amounts the player bets
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_bets_are_valid(bet_amounts: &vector<u64>, predicted_outcomes: &vector<u8>) {
        assert!(vector::length(bet_amounts) == vector::length(predicted_outcomes),
            ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes);
        assert!(vector::length(bet_amounts) > 0, ENumberOfBetsIsZero);
        assert!(vector::all(predicted_outcomes, |outcome| { *outcome <= ROYALFLUSH}), EPredictedOutcomeOutOfRange);
        assert!(vector::all(bet_amounts, |amount| { *amount > 0 }), EBetAmountIsZero);
    }
}






