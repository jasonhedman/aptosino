module aptosino::blackjack {

    use std::signer;
    use std::vector;

    use aptos_framework::event;
    use aptos_framework::object::{Self, Object};
    use aptos_framework::randomness;
    
    use aptosino::house;
    use aptosino::state_based_game;

    // constants
    
    const NUM_CARD_VALUES: u8 = 13;
    const NUM_CARD_SUITS: u8 = 4;
    
    // error codes
    
    /// The resolve is not valid
    const EResolveNotValid: u64 = 104;
    
    // game type
    
    struct BlackjackGame has drop {}
    
    /// A blackjack hand
    struct BlackjackHand has key {
        /// The address of the player
        player_address: address,
        /// The player's cards
        player_cards: vector<vector<u8>>,
        /// The dealer's cards
        dealer_cards: vector<vector<u8>>,
    }
    
    // events
    
    #[event]
    /// Emitted when a new hand is created
    struct HandCreated has store, drop {
        /// The address of the player
        player_address: address,
        /// The address of the hand object
        hand_address: address,
        /// The amount bet
        bet_amount: u64,
        /// The player's initial cards
        player_cards: vector<vector<u8>>,
        /// The dealer's initial card
        dealer_cards: vector<vector<u8>>
    }
    
    #[event]
    /// Emitted when a player hits
    struct PlayerHit has store, drop {
        /// The address of the player
        player_address: address,
        /// The address of the hand object
        hand_address: address,
        /// The player's new card
        new_card: vector<u8>
    }
    
    #[event]
    /// Emitted when a game is resolved
    struct GameResolved has store, drop {
        /// The address of the player
        player_address: address,
        /// The address of the hand object
        hand_address: address,
        /// The player's cards
        player_cards: vector<vector<u8>>,
        /// The dealer's cards
        dealer_cards: vector<vector<u8>>,
    }
    
    // admin functions
    
    /// Initializes the game mapping
    /// * creator: the admin signer
    public entry fun init(creator: &signer) {
        state_based_game::init(creator, BlackjackGame {});
    }
    
    /// Approves the game to use the house
    /// * admin: the admin signer
    public entry fun approve_game(admin: &signer) {
        house::approve_game(admin, BlackjackGame {});
    }
    
    /// Creates an instance of a blackjack hand
    /// * player: the player signer
    /// * bet_amount: the amount to bet
    public entry fun start_game(player: &signer, bet_amount: u64) acquires BlackjackHand {
        start_game_impl(
            player,
            bet_amount,
            vector[deal_card(), deal_card()],
            vector[deal_card()]
        );
    }

    /// Hits the player's hand
    /// * player: the player signer
    /// * blackjack_hand_obj: the blackjack hand object
    public entry fun hit(player: &signer) acquires BlackjackHand {
        hit_impl(get_player_hand(signer::address_of(player)), deal_card());
    }

    /// Stands the player's hand
    /// * player: the player signer
    /// * blackjack_hand_obj: the blackjack hand object
    public entry fun stand(player: &signer) acquires BlackjackHand {
        resolve_game(get_player_hand(signer::address_of(player)));
    }
    
    // private implementation functions
    
    /// Implementation of the start game function
    /// * player: the player signer
    /// * bet_amount: the amount to bet
    fun start_game_impl(
        player: &signer, 
        bet_amount: u64, 
        player_cards: vector<vector<u8>>,
        dealer_cards: vector<vector<u8>>
    ): Object<BlackjackHand> acquires BlackjackHand {
        let player_address = signer::address_of(player);
        
        let constructor_ref = state_based_game::create_game(
            player,
            bet_amount,
            BlackjackGame {}
        );

        move_to(&object::generate_signer(&constructor_ref), BlackjackHand {
            player_address,
            player_cards,
            dealer_cards,
        });

        let blackjack_hand_obj = object::object_from_constructor_ref<BlackjackHand>(&constructor_ref);
        let hand_address = object::object_address(&blackjack_hand_obj);
        // check for blackjack
        if(calculate_hand_value(get_player_cards(blackjack_hand_obj)) == 21) {
            // this is necessary for testing purposes, but in practice will always execute
            if(vector::length(&get_dealer_cards(blackjack_hand_obj)) != 2) {
                deal_to_house(blackjack_hand_obj, deal_card());
            };
            resolve_game(blackjack_hand_obj);
        };

        event::emit(HandCreated {
            player_address,
            hand_address,
            bet_amount,
            player_cards,
            dealer_cards
        });

        blackjack_hand_obj
    }
    
    /// Implementation of the hit function
    /// * blackjack_hand_obj: the blackjack hand object
    /// * new_card: the new card to add to the player's hand
    fun hit_impl(blackjack_hand_obj: Object<BlackjackHand>, new_card: vector<u8>) acquires BlackjackHand {
        let blackjack_hand = borrow_global_mut<BlackjackHand>(object::object_address(&blackjack_hand_obj));
        vector::push_back(&mut blackjack_hand.player_cards, new_card);
        event::emit(PlayerHit {
            player_address: blackjack_hand.player_address,
            hand_address: object::object_address(&blackjack_hand_obj),
            new_card
        });
        if(calculate_hand_value(blackjack_hand.player_cards) == 21 
            || calculate_hand_value(blackjack_hand.player_cards) == 0) {
            resolve_game(blackjack_hand_obj);
        };
    }
    
    /// Resolves the hand
    /// * blackjack_hand_obj: the blackjack hand object
    fun resolve_game(blackjack_hand_obj: Object<BlackjackHand>) acquires BlackjackHand {
        let hand_address = object::object_address(&blackjack_hand_obj);
        assert_resolve_is_at_valid(borrow_global<BlackjackHand>(hand_address));
        
        // dealer hits until 17 or higher
        while(calculate_hand_value(borrow_global<BlackjackHand>(hand_address).dealer_cards) < 17
            && calculate_hand_value(borrow_global<BlackjackHand>(hand_address).dealer_cards) != 0) {
            deal_to_house(blackjack_hand_obj, deal_card());
        };
        
        let BlackjackHand {
            player_address,
            player_cards,
            dealer_cards,
        } = move_from<BlackjackHand>(hand_address);
        
        let player_value = calculate_hand_value(player_cards);
        let dealer_value = calculate_hand_value(dealer_cards);
        let (payout_numerator, payout_denominator) = if(player_value == 0) {
            (0, 1) // player busts, dealer wins
        } else if(dealer_value == 0) { 
            (2, 1) // dealer busts, player wins
        } else if(player_value == 21 && vector::length(&player_cards) == 2) {
            if(dealer_value == 21 && vector::length(&dealer_cards) == 2) {
                (1, 1) // push, return bet to player
            } else {
                (5, 2) // player blackjack, player wins
            }
        } else if(dealer_value == 21 && vector::length(&dealer_cards) == 2) {
            (0, 1) // dealer blackjack, dealer wins
        } else if(player_value == dealer_value) {
            (1, 1) // push, return bet to player
        } else if (player_value > dealer_value) {
            (2, 1)  // player wins
        } else {
            (0, 1) // dealer wins
        };
        
        state_based_game::resolve_game(player_address, payout_numerator, payout_denominator, BlackjackGame {});
        
        event::emit(GameResolved {
            player_address,
            hand_address,
            player_cards,
            dealer_cards,
        });
    }
    
    /// Deals a card to the house
    /// * blackjack_hand_obj: the blackjack hand object
    /// * new_card: the new card to add to the house's hand
    fun deal_to_house(blackjack_hand_obj: Object<BlackjackHand>, new_card: vector<u8>) acquires BlackjackHand {
        let blackjack_hand = borrow_global_mut<BlackjackHand>(object::object_address(&blackjack_hand_obj));
        vector::push_back(&mut blackjack_hand.dealer_cards, new_card);
    }
    
    /// Deals a random card with random value and suit
    fun deal_card(): vector<u8> {
        let value = (randomness::u8_range(1, NUM_CARD_VALUES + 1));
        let suit = (randomness::u8_range(0, NUM_CARD_SUITS));
        vector[value, suit]
    }
    
    // getters
    
    #[view]
    /// Gets the player hand object
    /// * player_address: the address of the player
    public fun get_player_hand(player_address: address): Object<BlackjackHand> {
        state_based_game::get_game_object<BlackjackGame, BlackjackHand>(player_address)
    }
    
    #[view]
    /// Gets the player of a blackjack hand
    /// * blackjack_hand_obj: a reference to the blackjack hand object
    public fun get_player_address(blackjack_hand_obj: Object<BlackjackHand>): address acquires BlackjackHand {
        borrow_global<BlackjackHand>(object::object_address(&blackjack_hand_obj)).player_address
    }
    
    #[view]
    /// Gets the player's cards
    /// * blackjack_hand_obj: a reference to the blackjack hand object
    public fun get_player_cards(blackjack_hand_obj: Object<BlackjackHand>): vector<vector<u8>> acquires BlackjackHand {
        borrow_global<BlackjackHand>(object::object_address(&blackjack_hand_obj)).player_cards
    }
    
    #[view]
    /// Gets the dealer's cards
    /// * blackjack_hand_obj: a reference to the blackjack hand object
    public fun get_dealer_cards(blackjack_hand_obj: Object<BlackjackHand>): vector<vector<u8>> acquires BlackjackHand {
        borrow_global<BlackjackHand>(object::object_address(&blackjack_hand_obj)).dealer_cards
    }
    
    #[view]
    /// Gets the bet amount
    /// * blackjack_hand_obj: a reference to the blackjack hand object
    public fun get_bet_amount(player_address: address): u64 {
        state_based_game::get_player_bet_amount<BlackjackGame>(player_address)
    }
    
    /// Calculates the value of a vector of cards
    /// * cards: the cards to calculate the value of
    public fun calculate_hand_value(cards: vector<vector<u8>>): u8 {
        if(vector::any(&cards, |card| *vector::borrow(card, 0) == 1)) {
            calculate_hand_value_with_ace(cards)
        } else {
            calculate_hand_value_no_ace(cards)
        }
    }
    
    /// Calculates the value of a hand with no aces
    public fun calculate_hand_value_no_ace(cards: vector<vector<u8>>): u8 {
        let value = vector::fold(cards, 0, |sum, card| {
            let card_value = *vector::borrow(&card, 0);
            if(card_value > 10) { sum + 10 } else { sum + card_value }
        });
        if(value > 21) { 0 } else { value }
    }
    
    /// Calculates the value of a hand with aces; returns the ace-1 value if the ace-11 value is over 21
    /// * cards: the cards to calculate the value of
    public fun calculate_hand_value_with_ace(cards: vector<vector<u8>>): u8 {
        let values: vector<u8> = vector[0];
        vector::for_each(cards, |card| {
            let card_value = *vector::borrow(&card, 0);
            let i = 0;
            let length = vector::length(&values);
            while(i < length) {
                let value = vector::borrow_mut(&mut values, i);
                if(card_value == 1) {
                    *value = *value + 1;
                    vector::push_back(&mut values, *value + 10);
                } else if(card_value > 10) { *value = *value + 10; } 
                else { *value = *value + card_value; };
                i = i + 1;
            };
        });
        vector::fold(values, 0, |max, value| if(value <= 21 && value > max) { value } else { max })
    }
    
    // assert statements
    
    /// Asserts that the dealer is at 17 or higher
    /// * blackjack_hand: the blackjack hand to assert
    fun assert_resolve_is_at_valid(blackjack_hand: &BlackjackHand) {
        let player_hand_value = calculate_hand_value(blackjack_hand.player_cards);
        let dealer_hand_value = calculate_hand_value(blackjack_hand.dealer_cards);
        let player_blackjack = player_hand_value == 21 && vector::length(&blackjack_hand.player_cards) == 2;
        let bust = player_hand_value == 0 || dealer_hand_value == 0;
        let dealer_17_or_higher = calculate_hand_value(blackjack_hand.dealer_cards) >= 17;
        assert!(player_blackjack || bust || dealer_17_or_higher, EResolveNotValid);
    }
    
    // functions
    
    #[test_only]
    public fun test_start_game(
        player: &signer, 
        bet_amount: u64,
        player_cards: vector<vector<u8>>,
        dealer_cards: vector<vector<u8>>
    ): Object<BlackjackHand> acquires BlackjackHand {
        start_game_impl(player, bet_amount, player_cards, dealer_cards)
    }
    
    #[test_only]
    public fun test_hit(blackjack_hand_obj: Object<BlackjackHand>, new_card: vector<u8>) acquires BlackjackHand {
        hit_impl(blackjack_hand_obj, new_card);
    }
    
    #[test_only]
    public fun test_resolve_game(blackjack_hand_obj: Object<BlackjackHand>) acquires BlackjackHand {
        resolve_game(blackjack_hand_obj);
    }
    
    #[test_only]
    public fun test_deal_to_house(blackjack_hand_obj: Object<BlackjackHand>, new_card: vector<u8>) acquires BlackjackHand {
        deal_to_house(blackjack_hand_obj, new_card);
    }
}
