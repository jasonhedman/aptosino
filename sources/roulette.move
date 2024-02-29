module aptosino::roulette {

    use std::signer;
    use std::vector;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::house;

    // constants (remove)
    const NUM_OUTCOMES: u8 = 37;

    // bet pattern

    /// During initialization, the amount is verified to be non-zero, the number of predicted outcomes to be non-zero,
    /// the bet is compared to the player's balance, and the predicted outcomes are verified to be within the range of
    /// the machine's outcomes
    struct RouletteBet has store {
        /// The amount of the bet
        amount: u64,
        /// The numbers the player predicts
        predicted_outcomes: vector<u8>,
        /// Machine the bet is placed on
        machine: RouletteMachine,
    }


    /// machine pattern
    struct RouletteMachine has key {
        /// The address of the linked house
        house_address: address,
        /// The address of the developer (for royalties)
        developer_address: address,
        /// The edge taken by the developer
        developer_edge: u8,
        /// The number of outcomes on the wheel
        num_outcomes: u8,
        /// The categories of bets
        categories: vector<RouletteCategory>,
    }

    /// During initialization, the categories are verified to be valid, the house to be accurate, the developer
    /// to be the deployer, and the edge to be non-negative and less than 100
    fun new_machine(house_address: address, developer_address: address, developer_edge: u8,
                    num_outcomes: u8, category_values: &vector<vector<u8>>)
    : RouletteMachine {
        assert!(vector::length(category_values) > 0, EInvalidCategory);
        /// use the new_category function to create a new category for each value in category_values
        /// and store them in a vector use a for loop to iterate through category_values
        let categories = vector::empty<RouletteCategory>();
        let i = 0;
        while(i < vector::length(category_values)) {
            let category_values = vector::borrow(category_values, i);
            assert!(vector::length(category_values) > 0, EInvalidCategory);
            let category = new_category(
                category_values,
                (vector::length(category_values) as u8)
            );
            vector::push_back<RouletteCategory>(&mut categories, category);
            i = i + 1;
        };

        RouletteMachine {
            house_address,
            developer_address,
            developer_edge,
            num_outcomes,
            categories,
        }
    }

    /// Verify on initialization that the values are non-empty and unique and <= the size of the category
    struct RouletteCategory has store {
        /// The values of the category
        values: vector<u8>,
        /// The size of the category (aka 'Payout Numerator')
        size: u8,
    }

    fun new_category(values: &vector<u8>, size: u8)
    : RouletteCategory {
        /// The values must be non-empty and have the same length as the size
        assert!(vector::length(values) == (size as u64), EInvalidCategory);

        /// The values must all be unique and <= size (this is a nice gurarantee to have)
        let i = 0;
        while(i < vector::length(values)) {
            let j = i + 1;
            while(j < vector::length(values)) {
                assert!(vector::borrow<u8>(values, i) != vector::borrow<u8>(values, j), EInvalidCategory);
                assert!(*vector::borrow(values, j) <= size, EInvalidCategory);
                j = j + 1;
            };
            i = i + 1;
        };

        /// Dereference the values vector and create a new RouletteCategory
        RouletteCategory {
            values: *values,
            size,
        }
    }

    // error codes
    
    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The number of bets does not match the number of predicted outcomes
    const ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes: u64 = 102;
    /// The number of bets is zero
    const ENumberOfBetsIsZero: u64 = 103;
    /// The bet amount is zero
    const EBetAmountIsZero: u64 = 104;
    /// The number of predicted outcomes is zero for a bet
    const ENumberOfPredictedOutcomesIsZero: u64 = 105;
    /// A predicted outcome is out of range
    const EPredictedOutcomeOutOfRange: u64 = 106;
    /// Invalid category
    const EInvalidCategory: u64 = 107;

    // events

    #[event]
    /// Event emitted when the player spins the wheel
    struct SpinWheelEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amounts the player bets
        bet_amounts: vector<u64>,
        /// The numbers the player predicts for each bet
        predicted_outcomes: vector<vector<u8>>,
        /// The result of the spin
        result: u8,
        /// The payout to the player
        payout: u64,
    }

    // game functions

    /// Spins the wheel and pays out the player
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    public entry fun spin_wheel(
        player: &signer,
        bet_amount_inputs: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
    ) {
        let result = randomness::u8_range(0, NUM_OUTCOMES);
        spin_wheel_impl(player, bet_amount_inputs, predicted_outcomes, result);
    }

    /// Implementation of the spin_wheel function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_amounts: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    /// * result: the result of the spin
    fun spin_wheel_impl(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
        result: u8
    ) {
        let player_address = signer::address_of(player);
        let total_bet_amount = 0;
        vector::for_each(bet_amounts, |bet_amount| { total_bet_amount = total_bet_amount + bet_amount; });
        assert_player_has_enough_balance(player_address, total_bet_amount);

        assert_bets_are_valid(&bet_amounts, &predicted_outcomes);
        
        let total_payout = 0;
        
        let i = 0;
        // the length of bet_amounts and predicted_outcomes is already checked to be equal
        while(i < vector::length(&bet_amounts)) {
            let outcomes = vector::borrow(&predicted_outcomes, i);
            assert_predicted_outcome_is_valid(outcomes);
            let bet_lock = house::acquire_bet_lock(
                player_address,
                coin::withdraw<AptosCoin>(player, *vector::borrow(&bet_amounts, i)),
                (NUM_OUTCOMES as u64),
                vector::length(outcomes)
            );
            let payout = if(vector::any(outcomes, |outcome| { *outcome == result })) {
                house::get_max_payout(&bet_lock)
            } else {
                0
            };
            total_payout = total_payout + payout;
            house::release_bet_lock(bet_lock, payout);
            i = i + 1;
        };

        event::emit(SpinWheelEvent {
            player_address,
            bet_amounts,
            predicted_outcomes,
            result,
            payout: total_payout,
        });
    }
    
    // getters
    
    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * predicted_outcome: the numbers the player predicts
    public fun get_payout(bet_amount: u64, predicted_outcome: vector<u8>): u64 {
        bet_amount * (NUM_OUTCOMES as u64) / vector::length(&predicted_outcome) - house::get_fee_amount(bet_amount)
    }

    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Asserts that the number of bets and predicted outcomes are equal in length, non-empty, and non-zero
    /// * multiplier: the multiplier of the bet
    /// * bet_amounts: the amounts the player bets
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_bets_are_valid(bet_amounts: &vector<u64>, predicted_outcomes: &vector<vector<u8>>) {
        assert!(vector::length(bet_amounts) == vector::length(predicted_outcomes), 
            ENumberOfBetsDoesNotMatchNumberOfPredictedOutcomes);
        assert!(vector::length(bet_amounts) > 0, ENumberOfBetsIsZero);
        assert!(vector::all(predicted_outcomes, |outcomes| { vector::length(outcomes) > 0 }), 
            ENumberOfPredictedOutcomesIsZero);
        assert!(vector::all(bet_amounts, |amount| { *amount > 0 }), EBetAmountIsZero);
    }
    
    /// Asserts that each outcome in a vector of predicted outcomes is within the range of possible outcomes
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_predicted_outcome_is_valid(predicted_outcome: &vector<u8>) {
        vector::for_each(*predicted_outcome, |outcome| {
            assert!(outcome < NUM_OUTCOMES, EPredictedOutcomeOutOfRange);
        });
    }

    // test functions

    #[test_only]
    public fun test_spin_wheel(
        player: &signer,
        bet_amounts: vector<u64>,
        predicted_outcomes: vector<vector<u8>>,
        result: u8
    ) {
        spin_wheel_impl(player, bet_amounts, predicted_outcomes, result);
    }
}
