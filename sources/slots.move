module aptosino::slots {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use std::vector;

    use aptosino::house;

    // error codes

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The bet amount is invalid
    const EInvalidBetAmount: u64 = 102;
    /// The number of reels is invalid
    const EInvalidNumberReels: u64 = 102;
    /// The number of stops per reel is invalid
    const EInvalidNumberStops: u64 = 103;
    /// The symbol sequence is invalid
    const EInvalidSymbolSequence: u64 = 104;


    // events
    struct SlotMachine has drop {
        /// The number of visual reels (3, 4 or 5)
        num_reels: u8,
        /// The number of visual rows (3, 4 or 5)
        num_rows: u8,
        /// The number of stops per reel
        num_stops: u64,
        /// The symbol array of the slot machine (identical across all reels)
        symbol_sequence: vector<u8>,
        /// The number of lines active
        num_lines: u8,
        /// The payout table
        payout_table: vector<u64>,
    }

    #[event]
    /// Event emitted when the slots are spun
    struct SpinSlots has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount bet
        bet_amount: u64,
        /// The number of stops per reel
        num_stops: u64,
        /// The symbol array of the slot machine (identical across all lines)
        /// There can be duplicates in the array, which will be weighted accordingly
        /// There might be a joker symbol, which will be weighted accordingly as if
        /// it was a duplicate of all other symbols
        symbol_sequence: vector<u8>,
        /// The number of lines active
        num_lines: u8,
        /// The result of the spin
        result: vector<vector<u8>>,
        /// Return vector of winning lines numbered for front end
        winning_lines: vector<u8>,
        /// The payout of the spin
        payout: u64,
    }

    // game functions

    /// Rolls the dice and pays out the winnings to the player
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    public entry fun spin_slots(
        player: &signer,
        bet_amount_input: u64,
        num_lines: u64,
        num_reels: u64,
        num_stops: u64,
        symbol_sequence: vector<u64>,
        payout_table: vector<u64>
    ) {
        // Create a vector of vectors
        let result: vector<vector<u64>> = vector::empty();
        // Obtain mutable reference to the result vector
        let result_ref = &mut result;
        let i = 0;
        while (i < num_reels) {
            let reel = randomness::permutation(num_stops);
            // Translate the symbol sequence into a vector of symbols
            let reel_symbols: vector<u64> = vector::empty();
            let reel_symbols_ref = &mut reel_symbols;
            let j = 0;
            while (j < num_stops) {
                vector::push_back(reel_symbols_ref, symbol_sequence[reel[j]]);
                j = j + 1;
            };
            vector::push_back(result_ref, reel);
        };
        let payout = spin_slots_calc_payout(num_lines, num_reels, num_stops, symbol_sequence, payout_table, result);
    }



    fun spin_slots_calc_payout(
        num_lines: u64,
        num_reels: u64,
        num_stops: u64,
        symbol_sequence: vector<u64>,
        payout_table: vector<u64>,
        result: vector<vector<u64>>
    ) :u64 {
        let payout = 0;
        let i = 0;
        while (i < num_lines) {

        };
        payout
    }

    /// Implementation of the roll_dice function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_coins: the coins to bet
    /// * multiplier: the multiplier of the bet (the payout is bet * multiplier)
    /// * predicted_outcome: the number the player predicts (must be less than the multiplier)
    /// * result: the result of the spin
    fun spin_slots_impl(
        player: &signer,
        bet_amount: u64,
        multiplier: u64,
        predicted_outcome: u64,
        result: u64
    ) {
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);

        assert_bet_is_valid(multiplier, predicted_outcome);

        let bet_lock = house::acquire_bet_lock(
            player_address,
            coin::withdraw<AptosCoin>(player, bet_amount),
            multiplier
        );

        let payout = if (result == predicted_outcome) {
            house::get_max_payout(&bet_lock)
        } else {
            0
        };

        house::release_bet_lock(bet_lock, payout);

        event::emit(RollDiceEvent {
            player_address,
            bet_amount,
            multiplier,
            predicted_outcome,
            result,
            payout,
        });
    }

    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Asserts that the bet is valid
    /// * num_lines: the number of lines active
    /// * num_reels: the number of reels in the slot machine (3, 4 or 5)
    /// * num_stops: the number of stops per reel
    /// * symbol_sequence: the sequence of symbols
    /// * payout_table: the payout table
    /// * bet_amount: the amount to bet
    fun assert_bet_is_valid(
        num_lines: u64,
        num_reels: u64,
        num_stops: u64,
        symbol_sequence: vector<u64>,
        payout_table: vector<u64>,
        bet_amount: u64
    ) {
        assert!(bet_amount > 0, EInvalidBetAmount);
        assert!((num_reels >= 3) && (num_reels <= 5), EInvalidNumberReels);
        assert!((num_stops >= ) && (num_reels <= 5), EInvalidNumberReels);
        assert!(num_stops > 0, EInvalidNumberStops);
        assert!(symbol_sequence.length() > 0, EInvalidSymbolSequence);
        assert!(payout_table.length() > 0, EInvalidSymbolSequence);
    }

    // test functions

    #[test_only]
    public fun test_spin_wheel(
        player: &signer,
        bet_amount: u64,
        multiplier: u64,
        predicted_outcome: u64,
        result: u64
    ) {
        roll_dice_impl(player, bet_amount, multiplier, predicted_outcome, result);
    }
}