/// Conceptually roulette is a game of selecting a random number in a range of 0 to n. Any bet
/// placed on any combination of these numbers will be paid out according to the odds of that
/// number. The player may bet on multiple outcomes at once. We should be able to define "categories" for numbers
/// and then place bets on these categories. Traditional categories are:
/// - Red or Black
/// - Odd or Even
/// - Low (1-18) or High (19-36)
/// - Dozen (1-12, 13-24, 25-36)
/// - Column (1st, 2nd, 3rd)
/// But in order to encapsulate future possible extensions of this game, we will allow the user to define the categories
/// and the bet placed. Overlapping categories wouldn't multiply but pay out each according to their own odds.
module aptosino::roulette {




}