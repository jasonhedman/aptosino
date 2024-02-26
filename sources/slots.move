module aptosino::slots {

    use std::signer;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use std::vector;
    use std::vector::for_each;

    use aptosino::house;

    // error codes

    /// Player does not have enough balance to bet
    const EPlayerInsufficientBalance: u64 = 101;
    /// The bet amount is invalid
    const EInvalidBetAmount: u64 = 102;
    /// The number of reels is invalid
    const EInvalidNumberReels: u64 = 102;
    /// The number of visible rows is invalid
    const EInvalidNumberRows: u64 = 104;
    /// The number of stops per reel is invalid
    const EInvalidNumberStops: u64 = 105;
    /// The number of lines is invalid
    const EInvalidNumberLines: u64 = 105;
    /// The symbol sequence is invalid
    const EInvalidSymbolSequence: u64 = 106;
    /// The payout table is invalid
    const EInvalidPayoutTable: u64 = 107;

    // structs
    struct SlotMachine has drop, store {
        /// The number of visual reels / columns
        num_reels: u8,
        /// The number of visual stops / rows
        num_rows: u8,
        /// The number of stops per reel
        num_stops: u64,
        /// The symbol array of the slot machine (identical across all reels)
        /// Joker symbol is represented by -1
        symbol_sequence: vector<u8>,
        /// The payout table is a vector of vectors, where the first index
        /// is associated with a specific symbol and the second index is
        /// associated with the number of consecutive symbols in a line
        /// The payout is the product of the bet and the payout_table value
        /// associated with the symbol and the largest # of consecutive symbols
        payout_table: vector<vector<u8>>,
        /// The lines available to the player
        /// The lines are vectors of the indexes of the stops included numbered
        /// from top to bottom
        /// The practical bet size is divided by the number of lines
        lines: vector<vector<u8>>,
        /// Unit bet size
        unit_bet: u64,
    }

    /// Asserts that the SlotMachine is valid
    fun assert_slot_machine_is_valid(
        num_reels: u8,
        num_rows: u8,
        num_stops: u64,
        symbol_sequence: vector<u8>,
        payout_table: vector<vector<u8>>,
        lines: vector<vector<u8>>,
        unit_bet: u64,
    ) {
        assert!(num_reels > 0, EInvalidNumberReels);
        assert!(num_rows > 0, EInvalidNumberRows);
        assert!(num_stops > 0, EInvalidNumberStops);
        assert!(vector::length(&lines) > 0, EInvalidNumberLines);

        /// If any duplicate symbols are found, the payout table entry for each must be identical
        let i = 0;
        while (i < vector::length(&symbol_sequence)) {
            let j = i + 1;
            while (j < vector::length(&symbol_sequence)) {
                if (symbol_sequence[i] == symbol_sequence[j]) {
                    assert!(payout_table[i] == payout_table[j], EInvalidSymbolSequence);
                };
                j = j + 1;
            };
            i = i + 1;
        };

        /// The payout table must have the same number of entries as the symbol sequence
        assert!(vector::length(&symbol_sequence) == vector::length(&payout_table), EInvalidSymbolSequence);

        /// The payout table entries must be valid
        let i = 0;
            while(i < vector::length(&payout_table)) {
                /// The payout table entries must have the same length as the number of reels
                assert!(vector::length(&payout_table[i]) == (num_reels as u64), EInvalidPayoutTable);
            };

        /// The lines must be valid
        let i = 0;
        while (i < vector::length(&lines)) {
            let j = 0;
            assert!(vector::length(&lines[i]) == (num_reels as u64), EInvalidSymbolSequence);
            while (j < vector::length(&lines[i])) {
                assert!(lines[i][j] < num_rows && lines[i][j] < num_stops, EInvalidSymbolSequence);
                j = j + 1;
            };
            i = i + 1;
        };

        /// The slot machine is valid (helper)
        assert_slot_machine_is_EV_neutral(num_reels, num_rows, num_stops, symbol_sequence, payout_table, unit_bet);
    }

    /// Asserts that a bet on a single line is EV neutral
    /// The EV neutrality of bets on multiple lines is
    /// easily derived from this
    /// Duplicate symbols are allowed but must be identfied
    /// and the math adjusted accordingly
    /// Joker symbols are allowed and are represented by -1
    /// Each reel is spun independently
    /// The probability of each symbol is the same for each reel
    /// The probability of each symbol is the same for each stop
    /// The probability of each symbol is the same for each line
    /// A line contains a specific index for each reel
    /// The number of possible n of a kind is num_stops choose (n)
    /// The math for this is num_stops! / (n! * (num_stops - n)!)
    /// We need to subtract the possibilities of n of a 
    /// EV should equal unit_bet
    /// We multiply the number of n of a kind by the payout for n of a kind for each symbol
    /// We want to avoid floating point values, so we will do everything in terms of permutations
    fun calculate_EV_of_line(
        num_reels: u8,
        num_rows: u8,
        num_stops: u64,
        symbol_sequence: vector<u8>,
        payout_table: vector<vector<u8>>,
        unit_bet: u64,
    ) {
        let ev = 0;

    }

    #[event]
    /// Event emitted when the slots are spun
    struct SpinSlots has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount bet
        bet_amount: u64,
        /// The slot machine
        slot_machine: SlotMachine,
        /// The result of the spin
        result: vector<vector<u8>>,
        /// Return vector of winning lines (empty if no win)
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
        /// The payout table is a vector of vectors, where the first index
        /// is associated with a specific symbol and the second index is
        /// associated with the number of consecutive symbols in a line
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