module aptosino::deck {

    use std::vector;
    
    use aptos_framework::randomness;
    use aptosino::card;

    use aptosino::card::Card;

    // errors
    
    /// when trying to draw a card from an empty deck
    const EDeckIsEmpty: u64 = 1;
    /// when trying to draw more cards than the deck has
    const ENotEnoughCards: u64 = 2;
    
    // structs
    
    struct Deck has copy, drop, store {
        cards: vector<Card>
    }
    
    /// builds a deck of 52 cards, one for each rank-suit combination.
    public fun build_deck(): Deck {
        let cards: vector<Card> = vector[];
        for (suit in card::min_suit()..(card::max_suit() + 1)) {
            for (rank in card::min_rank()..(card::max_rank() + 1)) {
                vector::push_back(&mut cards, card::create(rank, suit));
            }
        };
        Deck {
            cards,
        }
    }
    
    /// shuffles a deck using the randomness::permutation function
    /// * deck - a mutable reference to a deck
    public fun shuffle_deck(deck: &mut Deck) {
        let cards_length = vector::length(&deck.cards);
        let permutation = randomness::permutation(cards_length);
        let new_cards: vector<Card> = vector[];
        for (i in 0..cards_length) {
            vector::push_back(
                &mut new_cards, 
                *vector::borrow(&deck.cards, *vector::borrow(&permutation, i))
            );
        };
        deck.cards = new_cards;
    }
    
    /// draws a card from the deck, removing it from the deck.
    /// * deck - a mutable reference to a deck
    public fun draw_card(deck: &mut Deck): Card {
        assert!(vector::length(&deck.cards) > 0, EDeckIsEmpty);
        vector::pop_back(&mut deck.cards)
    }
    
    /// draws n cards from the deck, removing them from the deck.
    /// * deck - a mutable reference to a deck
    /// * n - the number of cards to draw
    public fun draw_cards(deck: &mut Deck, n: u64): vector<Card> {
        assert!(vector::length(&deck.cards) >= n, ENotEnoughCards);
        let cards: vector<Card> = vector[];
        for (i in 0..n) {
            vector::push_back(&mut cards, draw_card(deck));
        };
        cards
    }
    
    /// gets the cards of a deck
    /// * deck - a reference to a deck
    public fun get_cards(deck: &Deck): vector<Card> {
        deck.cards
    }
    
    
}
