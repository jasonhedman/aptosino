module aptosino::roulette {

    use std::signer;
    use std::vector;

    use aptos_framework::aptos_coin::AptosCoin;
    use aptos_framework::coin;
    use aptos_framework::event;
    use aptos_framework::randomness;

    use aptosino::house;

    /// TO DO: IMPLEMENT INTERACTION WITH HOUSE

    // constants

    const MAX_ROWS: u8 = 100;
    const MAX_COLS: u8 = 100;

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
    /// The mines machine has invalid rows
    const EMinesMachineInvalidRows: u64 = 107;
    /// The mines machine has invalid columns
    const EMinesMachineInvalidCols: u64 = 108;
    /// The mines machine has invalid mines
    const EMinesMachineInvalidMines: u64 = 109;
    /// The mines machine has invalid mines
    const ECellIsRevealed: u64 = 110;

    // events

    struct MinesMachine has drop {
        revealed: vector<vector<u8>>,
        rows: u8,
        cols: u8,
        mines: u8,
    }

    #[event]
    /// Event emitted when the player plays the game
    struct CellSelected has drop, store {
        /// The address of the player
        player_address: address,
        /// The amount staked
        bet_amount: u64,
        /// The coordinates of the cell revealed
        predicted_coordinates: vector<u8>,
        /// The result of the selection (true if the cell is not a mine, false if it is)
        result: bool,
        /// The payout ratio (numerator and denominator)
        payout_ratio: vector<u8>,
    }

    // game functions

    /// Spins the wheel and pays out the player
    /// * player: the signer of the player account
    /// * bet_amount_inputs: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    public entry fun select_cell(
        player: &signer,
        bet_amount: u64,
        rows: u8,
        cols: u8,
        mines: u8,
        revealed: vector<vector<u8>>,
        predicted_coordinates: vector<u8>,
    ) {
        let mines_machine = MinesMachine {
            revealed,
            rows,
            cols,
            mines,
        };

        assert_mines_machine_valid(&mines_machine);

        select_cell_impl(player, bet_amount, predicted_coordinates, &mines_machine);
    }

    /// Implementation of the spin_wheel function, extracted to allow testing
    /// * player: the signer of the player account
    /// * bet_amounts: the amount to bet on each predicted outcome
    /// * predicted_outcomes: the numbers the player predicts for each corresponding bet
    /// * result: the result of the spin
    fun select_cell_impl(
        player: &signer,
        bet_amount: u64,
        predicted_coordinates: vector<u8>,
        mines_machine: &MinesMachine,
    ) {
        let player_address = signer::address_of(player);
        assert_player_has_enough_balance(player_address, bet_amount);

        assert_bet_is_valid(bet_amount);

        /// Implement the game logic here
        let explode_flag = false;
        let num_mines = mines_machine.mines;
        let i = 0;
        let mines = vector::empty<vector<u8>>();
        while (i < num_mines) {
            let mine = vector::empty<u8>();

            let mine_row = randomness::u8_range(0, mines_machine.rows);
            vector::push_back<u8>(mine, mine_row);
            let mine_col = randomness::u8_range(0, mines_machine.cols);
            vector::push_back<u8>(mine, mine_col);

            /// Ensure that the mine is unique, iterate until a unique mine is found
            if (!vector::contains<vector<u8>>(mines, mine)) {
                vector::push_back<vector<u8>>(mines, mine);
                i = i + 1;
            };

            /// The user busts
            if (vector::contains<vector<u8>>(predicted_coordinates, mine)) {
                explode_flag = true;
                break;
            };
        };

        let payout_ratio: vector<u8> = get_payout(bet_amount, MinesMachine, explode_flag);
        // If the
        if (explode_flag) {
            vector::borrow_mut(payout_ratio, 0) = 0;
        };

        event::emit<CellSelected>(
            CellSelected {
                player_address,
                bet_amount,
                predicted_coordinates,
                result: !explode_flag,
                payout_ratio,
            }
        );
    }

    // getters

    #[view]
    /// Returns the payout for a given bet
    public fun get_payout(bet_amount: u64, mines_machine: &MinesMachine, explode_flag: bool): vector<u8> {
        /// The number of remaining cells is the total number of cells minus the number of revealed cells
        let num_remaining_cells = mines_machine.rows * mines_machine.cols -
            vector::length<vector<u64>>(mines_machine.revealed);
        /// The multiplier numerator is the number of remaining cells that can be selected
        let multiplier_numerator = num_remaining_cells;
        /// The multiplier denominator is the number of cells that are not mines
        let multiplier_denominator = num_remaining_cells - mines_machine.mines;
        vector<u8>[multiplier_numerator, multiplier_denominator]
    }

    // assert statements

    /// Asserts that the player has enough balance to bet the given amount
    /// * player: the signer of the player account
    /// * amount: the amount to bet
    fun assert_player_has_enough_balance(player_address: address, amount: u64) {
        assert!(coin::balance<AptosCoin>(player_address) >= amount, EPlayerInsufficientBalance);
    }

    /// Asserts that the mines machine is valid
    fun assert_mines_machine_valid(mines_machine: &MinesMachine) {
        assert!(mines_machine.rows > 0 && mines_machine.rows < MAX_ROWS, EMinesMachineInvalidRows);
        assert!(mines_machine.cols > 0 && mines_machine.cols < MAX_COLS, EMinesMachineInvalidCols);
        /// Number of mines is less than the number of remaining cells
        assert!(mines_machine.mines > 0 && mines_machine.mines <
            (mines_machine.rows * mines_machine.cols - vector::length<vector<u8>>(mines_machine.revealed)), EMinesMachineInvalidMines);
    }

    /// Asserts that the number of bets and predicted outcomes are equal in length, non-empty, and non-zero
    /// * multiplier: the multiplier of the bet
    /// * bet_amounts: the amounts the player bets
    /// * predicted_outcome: the numbers the player predicts for each bet
    fun assert_bet_is_valid(bet: u64) {
        assert!(bet > 0, EBetAmountIsZero);
    }

    /// Asserts that each outcome in a vector of predicted outcomes is within the range of possible outcomes
    /// * predicted_outcome: the cell the player predicts
    fun assert_predicted_outcome_is_valid(predicted_outcome: &vector<u64>, revealed: &vector<vector<u64>>) {
        assert!(vector::borrow(predicted_outcome, 0) >= 0, EPredictedOutcomeOutOfRange);
        assert!(vector::borrow(predicted_outcome, 0) < MAX_ROWS, EPredictedOutcomeOutOfRange);
        assert!(vector::borrow(predicted_outcome, 1) >= 0, EPredictedOutcomeOutOfRange);
        assert!(vector::borrow(predicted_outcome, 1) < MAX_COLS, EPredictedOutcomeOutOfRange);
        assert!(!vector::contains<vector<u64>>(revealed, predicted_outcome), ECellIsRevealed);
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