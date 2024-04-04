module aptosino::card {

    use std::vector;
    use aptos_framework::randomness;

    // constants
    
    const MIN_RANK: u8 = 1;
    const MAX_RANK: u8 = 13;
    
    const MIN_SUIT: u8 = 0;
    const MAX_SUIT: u8 = 3;
    
    // error codes
    
    /// rank is invalid
    const ERankIsInvalid: u64 = 1;
    /// suit is invalid
    const ESuitIsInvalid: u64 = 2;

    /// A card in a standard deck of 52 cards.
    struct Card has copy, drop, store {
        /// the rank of the card, from 1 to 13.
        rank: u8,
        /// the suit of the card, from 0 to 3.
        suit: u8,
    }
    
    // factory
    
    /// creates a new card with the given rank and suit.
    /// * rank - the rank of the card, from 1 to 13.
    /// * suit - the suit of the card, from 0 to 3.
    public fun create(rank: u8, suit: u8): Card {
        assert!(rank >= MIN_RANK && rank <= MAX_RANK, ERankIsInvalid);
        assert!(suit >= MIN_SUIT && suit <= MAX_SUIT, ESuitIsInvalid);
        Card { rank, suit }
    }
    
    /// creates a random card
    public fun create_random_card(): Card {
        create(randomness::u8_range(MIN_RANK, MAX_RANK + 1), randomness::u8_range(MIN_SUIT, MAX_SUIT + 1))
    }
    
    /// creates n random cards
    /// * n - the number of cards to create
    public fun create_random_cards(n: u32): vector<Card> {
        let cards = vector::empty<Card>();
        for (i in 0..n) {
            vector::push_back(&mut cards, create_random_card());
        };
        cards
    }
    
    // getters

    /// gets the suit of a card
    public fun get_suit(card: &Card): u8 {
        card.suit
    }

    /// gets the rank of a card
    public fun get_rank(card: &Card): u8 {
        card.rank
    }
    
    // constant getters
    
    /// Returns the minimum rank of a card.
    public fun min_rank(): u8 {
        MIN_RANK
    }
    
    /// Returns the maximum rank of a card.
    public fun max_rank(): u8 {
        MAX_RANK
    }
    
    /// Returns the minimum suit of a card.
    public fun min_suit(): u8 {
        MIN_SUIT
    }
    
    /// Returns the maximum suit of a card.
    public fun max_suit(): u8 {
        MAX_SUIT
    }
}
