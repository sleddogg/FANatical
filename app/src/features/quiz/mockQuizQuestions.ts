import type { QuizQuestion, QuizSport } from "./types";

const footballQuestions: readonly QuizQuestion[] = [
  { id: "football-1", prompt: "How many points is a touchdown worth before the conversion attempt?", answers: ["3", "6", "7", "8"], correctAnswerIndex: 1 },
  { id: "football-2", prompt: "How many players from one team are normally on the field for a play?", answers: ["9", "10", "11", "12"], correctAnswerIndex: 2 },
  { id: "football-3", prompt: "How many quarters are played in a standard professional football game?", answers: ["2", "3", "4", "5"], correctAnswerIndex: 2 },
  { id: "football-4", prompt: "How many yards does an offense usually need to earn a first down?", answers: ["5", "10", "15", "20"], correctAnswerIndex: 1 },
  { id: "football-5", prompt: "How many points is a successful field goal worth?", answers: ["1", "3", "5", "6"], correctAnswerIndex: 1 },
  { id: "football-6", prompt: "What is the line where each play begins called?", answers: ["Line of scrimmage", "Goal line", "Hash line", "First-down line"], correctAnswerIndex: 0 },
  { id: "football-7", prompt: "How many points does a safety score?", answers: ["1", "2", "3", "6"], correctAnswerIndex: 1 },
  { id: "football-8", prompt: "Which position most often throws a forward pass?", answers: ["Center", "Linebacker", "Quarterback", "Safety"], correctAnswerIndex: 2 },
  { id: "football-9", prompt: "Which trophy is awarded to the Super Bowl champion?", answers: ["Heisman Trophy", "Grey Cup", "Commissioner's Trophy", "Vince Lombardi Trophy"], correctAnswerIndex: 3 },
  { id: "football-10", prompt: "How deep is an NFL end zone?", answers: ["5 yards", "10 yards", "15 yards", "20 yards"], correctAnswerIndex: 1 },
];

const hockeyQuestions: readonly QuizQuestion[] = [
  { id: "hockey-1", prompt: "How many periods are played in a standard regulation hockey game?", answers: ["2", "3", "4", "5"], correctAnswerIndex: 1 },
  { id: "hockey-2", prompt: "Which trophy is awarded to the NHL playoff champion?", answers: ["Hart Trophy", "Stanley Cup", "Vezina Trophy", "Calder Cup"], correctAnswerIndex: 1 },
  { id: "hockey-3", prompt: "How long is a standard minor penalty in the NHL?", answers: ["1 minute", "2 minutes", "4 minutes", "5 minutes"], correctAnswerIndex: 1 },
  { id: "hockey-4", prompt: "What is a hat trick?", answers: ["Three assists", "Three goals", "Three penalties", "Three shootout saves"], correctAnswerIndex: 1 },
  { id: "hockey-5", prompt: "What commonly creates a power play?", answers: ["An opponent takes a penalty", "A goalie freezes the puck", "A team calls timeout", "The game reaches overtime"], correctAnswerIndex: 0 },
  { id: "hockey-6", prompt: "How many players including the goalie normally take the ice for one team?", answers: ["4", "5", "6", "7"], correctAnswerIndex: 2 },
  { id: "hockey-7", prompt: "Which line is central to determining an offside entry?", answers: ["Goal line", "Red line", "Blue line", "Faceoff line"], correctAnswerIndex: 2 },
  { id: "hockey-8", prompt: "What is the protected area directly in front of the net called?", answers: ["Crease", "Slot box", "Circle", "Bench zone"], correctAnswerIndex: 0 },
  { id: "hockey-9", prompt: "What object is struck with a hockey stick during play?", answers: ["Ball", "Disc", "Puck", "Stone"], correctAnswerIndex: 2 },
  { id: "hockey-10", prompt: "How many skaters per side play regular-season NHL overtime?", answers: ["2", "3", "4", "5"], correctAnswerIndex: 1 },
];

const baseballQuestions: readonly QuizQuestion[] = [
  { id: "baseball-1", prompt: "How many outs end one half-inning?", answers: ["2", "3", "4", "6"], correctAnswerIndex: 1 },
  { id: "baseball-2", prompt: "How many innings are scheduled in a standard professional baseball game?", answers: ["7", "8", "9", "10"], correctAnswerIndex: 2 },
  { id: "baseball-3", prompt: "How many bases make up the baseball diamond, including home plate?", answers: ["3", "4", "5", "6"], correctAnswerIndex: 1 },
  { id: "baseball-4", prompt: "What is a fair ball hit over the outfield fence called?", answers: ["Double", "Home run", "Sacrifice", "Ground-rule out"], correctAnswerIndex: 1 },
  { id: "baseball-5", prompt: "How many strikes normally retire a batter?", answers: ["2", "3", "4", "5"], correctAnswerIndex: 1 },
  { id: "baseball-6", prompt: "How many balls normally award a batter first base?", answers: ["3", "4", "5", "6"], correctAnswerIndex: 1 },
  { id: "baseball-7", prompt: "Which player delivers the ball from the mound?", answers: ["Catcher", "Pitcher", "Shortstop", "Center fielder"], correctAnswerIndex: 1 },
  { id: "baseball-8", prompt: "What does RBI stand for?", answers: ["Runner Base Index", "Runs Batted In", "Regulation Batting Inning", "Run Between Innings"], correctAnswerIndex: 1 },
  { id: "baseball-9", prompt: "Where does the catcher normally position themselves?", answers: ["Behind home plate", "At first base", "On the mound", "In center field"], correctAnswerIndex: 0 },
  { id: "baseball-10", prompt: "What is MLB's championship series called?", answers: ["Pennant Cup", "World Series", "Commissioner's Final", "Diamond Championship"], correctAnswerIndex: 1 },
];

const basketballQuestions: readonly QuizQuestion[] = [
  { id: "basketball-1", prompt: "How many players from one team are normally on the court?", answers: ["4", "5", "6", "7"], correctAnswerIndex: 1 },
  { id: "basketball-2", prompt: "How many points is a standard field goal inside the arc worth?", answers: ["1", "2", "3", "4"], correctAnswerIndex: 1 },
  { id: "basketball-3", prompt: "How many points is a made shot beyond the three-point line worth?", answers: ["1", "2", "3", "4"], correctAnswerIndex: 2 },
  { id: "basketball-4", prompt: "How many points is a successful free throw worth?", answers: ["1", "2", "3", "4"], correctAnswerIndex: 0 },
  { id: "basketball-5", prompt: "How many quarters are played in an NBA game?", answers: ["2", "3", "4", "5"], correctAnswerIndex: 2 },
  { id: "basketball-6", prompt: "How many seconds are on the NBA shot clock?", answers: ["20", "24", "30", "35"], correctAnswerIndex: 1 },
  { id: "basketball-7", prompt: "What is bouncing the ball while moving called?", answers: ["Screening", "Dribbling", "Posting", "Rebounding"], correctAnswerIndex: 1 },
  { id: "basketball-8", prompt: "What is gaining possession after a missed shot called?", answers: ["A rebound", "An assist", "A steal", "A screen"], correctAnswerIndex: 0 },
  { id: "basketball-9", prompt: "What is a pass that directly leads to a basket called?", answers: ["A turnover", "An assist", "A block", "A charge"], correctAnswerIndex: 1 },
  { id: "basketball-10", prompt: "What is the NBA championship round called?", answers: ["The Finals", "The World Series", "The Final Four", "The Super Cup"], correctAnswerIndex: 0 },
];

export const mockQuizQuestionSets: Readonly<Record<QuizSport, readonly QuizQuestion[]>> = {
  Football: footballQuestions,
  Hockey: hockeyQuestions,
  Baseball: baseballQuestions,
  Basketball: basketballQuestions,
};
