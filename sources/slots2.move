/// Different approach: slot machine "symbols" are always unique numbers from 1 to num_stops.
/// A single "unit-bet" takes the form of a line (vector<u64>), a vector of symbols (vector<u64>), and a mulitplier (u64).
/// A unit-bet must have vector::length(line) == vector::length(symbols) and has a probability of winning equal to 1 / size(statespace),
/// and represents a call on the symbols which will appear on a single line. The weighted probability is multiplier / size(statespace).
/// A "sub-bet" takes the form of a line (vector<u64>) a vector of symbols (vector<u64>), and multiplier (u64).
/// The key difference between a sub-bet and a unit-bet is that a sub-bet can have a vector of symbols of any length where
/// 0 <= length <= num_reels. If the length is less than num_reels then the bet will be considered a call on the vector
/// to exist in sequence as a subset of the vector represented by the line in the result. Such a bet is multplied into many
/// unit-bets. The EV of a sub-bet is the sum of the EVs of the unit-bets it is multiplied into.
/// In a roulette game, we can treat these sub-bets as individual bets and verify that each is EV 0.
/// In a slot game, the EV of a sub-bet can be positive or negative so long as the EV of a bet,
/// which is the sum of the EVs of its sub-bets, equals 0. (We want the overall multiplier to be 1 for simplicity.)
/// A bet is a vector of sub-bets.