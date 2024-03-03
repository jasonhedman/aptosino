/// https://math.hawaii.edu/~ramsey/Probability/PokerHands.html
/// Allow people to bet on the above categories in a 5 card hand of poker.
/// Kind of an abstraction of roulette.
/// Number of possible hands: 2,598,960
/// Intuitively exclusive categories (i.e. a hand can't be both a single pair and a triple)
/// Single Pair: 1098240
/// Two Pair: 123552
/// Triple: 54912
/// Full House: 3744
/// Four of a Kind: 624
/// Intuitively non-exclusive categories:
/// Straight: 10240
/// Flush: 5144
/// Straight Flush: 40
/// Royal Flush: 4
/// None: 1302540 - 9 possible categories

module aptosino::poker {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::house;

    // error codes

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The predicted outcome is 0 or greater than or equal to the maximum outcome
    const EPredictedOutcomeInvalid: u64 = 102;
    /// A card object is invalid (should not happen)
    const ECardInvalid: u64 = 103;
    /// A deck object is invalid (should not happen)
    const EDeckInvalid: u64 = 104;

    // Structs

    /// A deck is a vector of cards (in this module we force a standard deck of 52 cards)
    struct Card has copy, drop{
        suit: u64,
        rank: u64,
    }

    // helper functions

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

    // events

    #[event]
    /// Event emitted when the dice are rolled
    struct DealCardsEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount of each bet
        bet_amounts: vector<u64>,
        /// The hands the player bet on
        predicted_outcomes: vector<u64>,
        /// The result of the spin
        result: u64,
        /// The payout to the player
        payout: u64,
    }

    // game functions

    /// Deals the cards and pays out the player according to his bet
    public entry fun deal_cards(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<u64>
    ) {
        assert_predicted_outcomes_are_valid(predicted_outcomes);

        deal_cards_impl(player, bet_amount_inputs, predicted_outcomes);
    }

    /// Implementation of the roll_dice function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    /// * result: the result of the spin
    fun deal_cards_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u64>,
    ) {
        let player_address = signer::address_of(player);
        let total_bet_amount = 0;
        vector::for_each(bet_amounts, |bet_amount| { total_bet_amount = total_bet_amount + bet_amount; });
        assert_player_has_enough_balance(player_address, total_bet_amount);

        let deck = build_deck();

        assert_deck_is_valid(deck);

        let shuffle = randomness::permutation(52);
        let cards_dealt: vector<Card> = vector::empty<Card>();
        while (vector::length(cards_dealt) < 5) {
            let card = vector::borrow<Card>(&deck, vector::borrow<u64>(&shuffle, cards_dealt));
            vector::push_back<Card>(cards_dealt, card);
        };

        /// Empty = no hands, can be bet on with 0
        let hands = get_dealt_hands_from_cards(cards_dealt);
    }

    /// Identify hands in the dealt cards and return a vector containing all the hands, empty if none
    fun get_dealt_hands_from_cards(cards: vector<Card>): vector<u64> {
        let flush = false;

        let hands = vector::empty<u64>();

        let ranks_found = vector::empty<u64>();
        let suits_found = vector::empty<u64>();

        vector::for_each(cards, |card| {
            if (!vector::contains(ranks_found, card.rank)) {
                vector::push_back<u64>(ranks_found, card.rank);
            };
            if (!vector::contains(suits_found, card.suit)) {
                vector::push_back<u64>(suits_found, card.suit);
            };
        });

        if (vector::length(suits_found) == 1) {
            /// Flush
            vector::push_back<u64>(hands, 7);
            flush = true;
        };

        if (vector::length(suits_found) == 2) {
            if (check_flush(suits_found)) {
                /// Flush
                vector::push_back<u64>(hands, 7);
                flush = true;
            };
        };

        if (vector::length(ranks_found) == 5) {
            if (check_straight(ranks_found)) {
                /// Straight
                vector::push_back<u64>(hands, 6);
                /// Straight flush
                if (flush) {
                    vector::push_back<u64>(hands, 8);
                };
                /// Royal flush
                if (get_highest_rank(ranks_found) == 14) {
                    vector::push_back<u64>(hands, 9);
                };
            };
        };

        if (vector::length(ranks_found) == 4) {
            /// Single pair
            vector::push_back<u64>(hands, 1);
        };

        if (vector::length(ranks_found) == 3) {
            if (check_triple(ranks_found)) {
                /// Triple
                vector::push_back<u64>(hands, 3);
            } else {
                /// Two pair
                vector::push_back<u64>(hands, 2);
            };
        };

        if (vector::length(ranks_found) == 2) {
            if (check_four_of_a_kind(ranks_found)) {
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

    /// Check if the cards form a flush, hand is guranteed to have 2 suits (or else we know it's not a flush)
    fun check_flush(suits_found: &vector<u64>): bool {
        let suit_1 = vector::borrow(suits_found, 0);
        let suit_1_count = 0;
        let suit_2 = vector::borrow(suits_found, 1);
        let suit_2_count = 0;
        vector::for_each(cards, |card| {
            if (card.suit == suit_1) {
                suit_1_count = suit_1_count + 1;
            };
            if (card.suit == suit_2) {
                suit_2_count = suit_2_count + 1;
            };
        });
        if (suit_1_count >= 4 || suit_2_count >= 4) {
            true
        };
        false
    }

    /// Check if the cards form a straight, ranks are guranteed to be unique
    /// Aces can be high (14) or low(1), they are represented as 1 in the cards
    fun check_straight(ranks_found: &vector<u64>): bool {
        let ranks = vector::empty<u64>();
        let high_ace = false;

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
    // getters

    #[view]
    /// Returns the multiplier for a given bet
    /// * predicted_outcome: the hand the player predicted, represented as a number
    /// Returns: the multiplier for the bet as a vector, where the first element
    /// is the numerator and the second element is the denominator
    public fun get_bet_multiplier(predicted_outcome: u64): vector<u64> {
        assert!(predicted_outcome < 9 && predicted_outcome > 0, EPredictedOutcomeInvalid);
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

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Checks that the predicted outcomes are valid
    fun assert_predicted_outcomes_are_valid(predicted_outcomes: vector<u64>) {
        assert!(vector::all(&predicted_outcomes, |hand| {hand < 10 && hand > 0}), EPredictedOutcomeInvalid);
    }

    /// Checks that a card is valid
    /// * card: the card to check
    /// Returns: true if the card is valid
    /// Panics: if the card is invalid
    fun assert_card_is_valid(card: Card): bool {
        assert!(card.suit < 4, ECardInvalid);
        assert!(card.rank < 14, ECardInvalid);
        true
    }

    /// Checks that a deck is valid
    /// * deck: the deck to check
    /// Panics: if the deck is invalid
    fun assert_deck_is_valid(deck: vector<Card>) {
        assert!(vector::length<Card>(deck) == 52, EDeckInvalid);
        assert!(vector::all(&deck, |card| {assert_card_is_valid(card)}), EDeckInvalid);
    }

    // test functions

    #[test_only]
    public fun test_deal_cards(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<u64>,
    ) {
        roll_dice_impl(player, bet_amount, max_outcome, predicted_outcome, result);
    }
}
