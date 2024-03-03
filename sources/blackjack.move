module aptosino::blackjack {

    use std::signer;
    use std::vector;
    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::coin::Coin;
    use aptos_framework::event;
    use aptos_framework::object;
    use aptos_framework::object::{DeleteRef, Object};
    use aptos_framework::randomness;
    use aptosino::house;

    // constants
    
    const NUM_CARD_VALUES: u8 = 13;
    const NUM_CARD_SUITS: u8 = 4;
    
    // error codes

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The predicted outcome is 0 or greater than or equal to the maximum outcome
    const ESignerIsNotPlayer: u64 = 102;
    
    // game type
    
    struct BlackjackGame has drop {}
    
    // structs
    
    struct BlackjackHand has key {
        player_address: address,
        player_cards: vector<vector<u8>>,
        dealer_cards: vector<vector<u8>>,
        delete_ref: DeleteRef,
        bet: Coin<AptosCoin>
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
        /// The amount won
        amount_won: u64
    }
    
    // admin functions
    
    public entry fun approve_game(admin: &signer) {
        house::approve_game(admin, BlackjackGame {})
    }
    
    public entry fun start_game(player: &signer, bet_amount: u64) {
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);
        
        let player_cards = vector[deal_card(), deal_card()];
        let dealer_cards = vector[deal_card()];
        
        let constructor_ref = object::create_object(house::get_house_address());
        
        move_to(&object::generate_signer(&constructor_ref), BlackjackHand {
            player_address,
            player_cards,
            dealer_cards,
            delete_ref: object::generate_delete_ref(&constructor_ref),
            bet: coin::withdraw(player, bet_amount)
        });
        
        event::emit(HandCreated {
            player_address,
            hand_address: object::object_address(&object::object_from_constructor_ref<BlackjackHand>(&constructor_ref)),
            bet_amount,
            player_cards,
            dealer_cards
        });
    }
    
    public entry fun hit(player: &signer, blackjack_hand_obj: Object<BlackjackHand>) acquires BlackjackHand {
        let hand_address = object::object_address(&blackjack_hand_obj);
        let blackjack_hand = borrow_global_mut<BlackjackHand>(hand_address);
        assert_signer_is_player(player, blackjack_hand);
        let new_card = deal_card();
        vector::push_back(&mut blackjack_hand.player_cards, new_card);
        event::emit(PlayerHit {
            player_address: blackjack_hand.player_address,
            hand_address,
            new_card
        });
        if(calculate_hand_value(blackjack_hand.player_cards) >= 21) {
            resolve_game(blackjack_hand_obj);
        };
    }
    
    public entry fun stand(player: &signer, blackjack_hand_obj: Object<BlackjackHand>) acquires BlackjackHand {
        let blackjack_hand = borrow_global<BlackjackHand>(object::object_address(&blackjack_hand_obj));
        assert_signer_is_player(player, blackjack_hand);
        resolve_game(blackjack_hand_obj);
    }
    
    fun resolve_game(blackjack_hand_obj: Object<BlackjackHand>) acquires BlackjackHand {
        let hand_address = object::object_address(&blackjack_hand_obj);
        let BlackjackHand {
            player_address,
            player_cards,
            dealer_cards,
            bet,
            delete_ref
        } = move_from<BlackjackHand>(hand_address);
        let player_balance_before = coin::balance<AptosCoin>(player_address);
        let player_value = calculate_hand_value(player_cards);
        let dealer_value = calculate_hand_value(dealer_cards);
        if(player_value == dealer_value) {
            // push, return bet to player
            coin::deposit(player_address, bet);
        } else if (player_value > dealer_value) {
            // player wins
            let multiplier_numerator = if(player_value == 21 && vector::length(&player_cards) == 2) {
                5 // blackjack
            } else {
                4 // normal win
            };
            house::pay_out(player_address, bet, multiplier_numerator, 2, BlackjackGame {});
        } else {
            // dealer wins
            house::pay_out(player_address, bet, 0, 1, BlackjackGame {});
        };
        object::delete(delete_ref);
        
        let player_balance_after = coin::balance<AptosCoin>(player_address);
        let amount_won = if(player_balance_after > player_balance_before) {
            player_balance_after - player_balance_before
        } else {
            0
        };
        
        event::emit(GameResolved {
            player_address,
            hand_address,
            player_cards,
            dealer_cards,
            amount_won
        });
    }
    
    // internal functions
    
    fun deal_card(): vector<u8> {
        let value = (randomness::u8_range(0, NUM_CARD_VALUES));
        let suit = (randomness::u8_range(0, NUM_CARD_SUITS));
        vector[value, suit]
    }
    
    fun calculate_hand_value(cards: vector<vector<u8>>): u8 {
        if(vector::any(&cards, |card| *vector::borrow(card, 0) == 0)) {
            calculate_hand_value_with_ace(cards)
        } else {
            calculate_hand_value_no_ace(cards)
        }
    }
    
    fun calculate_hand_value_no_ace(cards: vector<vector<u8>>): u8 {
        let value = 0;
        vector::for_each(cards, |card| {
            let card_value = *vector::borrow(&card, 0);
            if (card_value > 9) {
                value = value + 10;
            } else {
                value = value + card_value + 1;
            }
        });
        value
    }
    
    fun calculate_hand_value_with_ace(cards: vector<vector<u8>>): u8 {
        let value_1 = 0;
        let value_2 = 0;
        vector::for_each(cards, |card| {
            let card_value = *vector::borrow(&card, 0);
            if (card_value > 9) {
                value_1 = value_1 + 10;
                value_2 = value_2 + 10;
            } else if(card_value == 0) {
                value_1 = value_1 + 1;
                value_2 = value_2 + 11;
            } else {
                value_1 = value_1 + card_value + 1;
                value_2 = value_2 + card_value + 1;
            }
        });
        if(value_2 > 21) {
            value_1
        } else {
            value_2
        }
    }
    
    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player_address: the address of the player
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }
    
    /// Asserts that the given signer is the player of the given blackjack hand
    /// * player: the signer to assert
    /// * blackjack_hand: the blackjack hand to assert
    fun assert_signer_is_player(player: &signer, blackjack_hand: &BlackjackHand) {
        assert!(signer::address_of(player) == blackjack_hand.player_address, ESignerIsNotPlayer);
    }
}
