module aptosino::slots {

    use std::signer;
    use std::vector;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

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
    /// The machines offered lines are invalid
    const EInvalidLines: u64 = 105;
    /// The symbol sequence is invalid
    const EInvalidSymbolSequence: u64 = 106;
    /// The payout table is invalid
    const EInvalidPayoutTable: u64 = 107;

    // constants
    const MAX_REELS: u8 = 5;
    const MAX_ROWS: u8 = 5;
    const MAX_STOPS: u64 = 100;
    const MAX_LINES: u64 = 100;

    // structs
    struct SlotMachine has drop {
        /// The number of visual reels / columns
        num_reels: u8,
        /// The number of visual stops / rows
        /// Indices 0 - num_rows - 1 of our shuffled symbol array will be "visible" on the screen
        num_rows: u8,
        /// The number of stops per reel
        num_stops: u64,
        /// The symbol array of the slot machine (each symbol is represented by a unique u8)
        symbol_sequence: vector<u8>,
        /// The frequency of each symbol in the symbol_sequence
        symbol_frequencies: vector<u8>,
        /// The payout table is a vector of vectors, where the ith index
        /// is associated with the respective symbol Y_i in the symbol_sequence and the
        /// internal index is associated with the max number of consecutive Y_i's in a line
        /// obtained by the player. The value at the internal index is the payout multiplier.
        payout_table: vector<vector<u8>>,
        /// The lines available to the player
        /// The lines are vectors, with one entry per reel, with entry values indicating the of the stop
        /// included in the line for this reel, from "top" to "bottom" or from 0 to num_rows - 1
        lines: vector<vector<u8>>,
    }

    // events

    #[event]
    /// Event emitted when the player spins the wheel
    struct SpinSlotsEvent has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount of each bet
        bet_amounts: vector<u64>,
        /// The numbers the player predicts for each bet
        predicted_outcomes: vector<vector<u8>>,
        /// The result of the spin
        result: u8,
        /// The payout to the player
        payout: u64,
    }

    // public functions
    public entry fun spin_slots(
        player: &signer,
        bet_amount_input: u64,
        num_reels: u8,
        num_rows: u8,
        num_stops: u64,
        symbol_sequence: vector<u8>,
        symbol_frequencies: vector<u8>,
        payout_table: vector<vector<u8>>,
        lines: vector<vector<u8>>,
    ) {
        let slot_machine = SlotMachine {
            num_reels,
            num_rows,
            num_stops,
            symbol_sequence,
            symbol_frequencies,
            payout_table,
            lines,
        };
        spin_slots_impl(player, bet_amount_input, slot_machine);
    }

    fun spin_slots_impl(
        player: &signer,
        bet_amount_input: u64,
        slot_machine: SlotMachine,
    ) {
        /// convert the frequency of each symbol to actual occurrences in a vector
        
    }


    // getters

    #[view]
    /// Returns the payout for a given bet
    /// * bet_amount: the amount to bet
    /// * predicted_outcome: the numbers the player predicts
    public fun get_payout(bet_amount: u64, predicted_outcome: vector<u8>): u64 {
        if(vector::all(&predicted_outcome, |outcome| { *outcome < NUM_OUTCOMES })) {
            bet_amount * (NUM_OUTCOMES as u64) / vector::length(&predicted_outcome) - house::get_fee_amount(bet_amount)
        } else {
            0
        }
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

    /// Asserts that the SlotMachine is valid
    fun assert_slot_machine_is_valid(
        slot_machine: &SlotMachine,
    ) {
        /// The slot machine must have appropriate # of reels, rows, stops, lines
        assert_basic_parameters_are_valid(slot_machine);

        /// Assert symbols and frequencies are valid
        assert_symbols_and_frequencies_are_valid(slot_machine);

        /// Asserts that the payout table is valid
        assert_payout_table_is_valid(slot_machine);

        /// Asserts that the lines are valid
        assert_lines_are_valid(slot_machine);

        /// Asserts that the slot machine is fair
        assert_slot_machine_is_fair(slot_machine);
    }

    /// TODO: Implement this function
    /// EV should equal 1 as we are dealing in multipliers
    fun assert_slot_machine_is_fair_expected_value(
        slot_machine: &SlotMachine,
    ) {
        /// Calculate the total number of possible outcomes
        let total_outcomes = 1;
        let i = 0;
        while (i < slot_machine.num_reels) {
            total_outcomes = total_outcomes * slot_machine.num_stops;
            i = i + 1;
        };

    }

    fun assert_lines_are_valid(
        slot_machine: &SlotMachine,
    ) {
        /// Each line must have the same number of entries as the number of reels
        assert!(vector::all<vector<u8>>(slot_machine.lines, |line|
            { vector::length<u8>(line) == slot_machine.num_reels
                && (vector::all<u8>(line, |stop| {
                /// Stops included in line must be within the number of rows and stops
                stop < slot_machine.num_rows &&
                    stop < slot_machine.num_stops &&
                /// Stops included in line are positively indexed
                stop >= 0
            }))
            }), EInvalidLines);
    }

    fun assert_payout_table_is_valid(
        slot_machine: &SlotMachine,
    ) {
        /// The payout table must have the same number of entries as the symbol sequence
        assert!(vector::length<u8>(slot_machine.payout_table) ==
            vector::length<vector<u8>>(slot_machine.symbol_sequence), EInvalidPayoutTable);

        /// The payout table entries must be valid (length of each entry must be equal to the number of reels)
        assert!(vector::all<vector<u8>>(slot_machine.payout_table, |entry|
            { vector::length<u8>(entry) == slot_machine.num_reels }), EInvalidPayoutTable);
    }

    fun assert_symbols_and_frequencies_are_valid(
        slot_machine: &SlotMachine,
    ) {
        assert!(vector::length<u8>(slot_machine.symbol_sequence) == vector::length<u8>(slot_machine.symbol_frequencies),
            EInvalidSymbolSequence);
        assert!(vector::all<u8>(slot_machine.symbol_frequencies, |frequency| { frequency > 0 }),
            EInvalidSymbolSequence);

        /// sum of frequencies must be equal to the number of stops
        let accumulator = 0;
        vector::for_each<u8>(slot_machine.symbol_frequencies, |frequency| {
            accumulator = accumulator + frequency;
        });
        assert!(accumulator == slot_machine.num_stops, EInvalidSymbolSequence);

        /// Each symbol must be unique
        let i = 0;
        /// Begins at index 0, comparing to all after it, then moves to index 1, comparing to all after it, and so on
        while (i < vector::length<u8>(slot_machine.symbol_sequence)) {
            let j = i + 1;
            while (j < vector::length<u8>(slot_machine.symbol_sequence)) {
                assert!(vector::borrow<u8>(slot_machine.symbol_sequence, i) !=
                    vector::borrow<u8>(slot_machine.symbol_sequence, j),
                    EInvalidSymbolSequence);
                j = j + 1;
            };
            i = i + 1;
        };
    }

    /// Asserts that the basic parameters of the SlotMachine are valid
    fun assert_basic_parameters_are_valid(
        slot_machine: &SlotMachine,
    ) {
        assert!(slot_machine.num_reels < MAX_REELS && slot_machine.num_reels > 0, EInvalidNumberReels);
        assert!(slot_machine.num_rows < MAX_ROWS && slot_machine.num_rows > 0, EInvalidNumberRows);
        assert!(slot_machine.num_stops < MAX_STOPS && slot_machine.num_stops > 0, EInvalidNumberStops);
        assert!(vector::length<u8>(slot_machine.lines) < MAX_LINES && vector::length<u8>(slot_machine.lines) > 0,
            EInvalidLines);
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