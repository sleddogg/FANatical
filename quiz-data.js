const quizzes = {
  
  nhl: {
    rookie: [
      {
        id: "nhl-rookie-1",
        title: "NHL Rookie Quiz 1",
        questions: [
          {
            question: "How many periods are in a standard NHL game?",
            answers: ["2", "3", "4", "5"],
            correct: 1
          },
          {
            question: "What trophy is awarded to the NHL playoff champion?",
            answers: ["Hart Trophy", "Stanley Cup", "Norris Trophy", "Vezina Trophy"],
            correct: 1
          }
        ]
      }
    ],

    grinder: [
      {
        id: "nhl-grinder-1",
        title: "NHL Grinder Quiz 1",
        questions: [
          {
            question: "How long is a minor penalty in the NHL?",
            answers: ["1 minute", "2 minutes", "4 minutes", "5 minutes"],
            correct: 1
          },
          {
            question: "What is a power play?",
            answers: ["A team has more players because the opponent took a penalty", "A team pulls its goalie", "A team scores twice in a row", "A team starts overtime"],
            correct: 0
          }
        ]
      }
    ],

    "league-average": [
      {
        id: "nhl-league-average-1",
        title: "NHL League Average Quiz 1",
        questions: [
          {
            question: "What is icing?",
            answers: ["Shooting the puck over the glass", "Shooting the puck from behind centre past the opponent’s goal line untouched", "Freezing the puck along the boards", "Covering the puck with a glove"],
            correct: 1
          },
          {
            question: "What is a hat trick?",
            answers: ["3 assists in one game", "3 goals in one game", "3 penalties in one period", "3 saves in a shootout"],
            correct: 1
          }
        ]
      }
    ],

    star: [
      {
        id: "nhl-star-1",
        title: "NHL Star Quiz 1",
        questions: [
          {
            question: "Which trophy is awarded to the NHL regular-season MVP?",
            answers: ["Vezina Trophy", "Hart Trophy", "Norris Trophy", "Selke Trophy"],
            correct: 1
          },
          {
            question: "Which trophy is awarded to the NHL’s best defenceman?",
            answers: ["Calder Trophy", "Norris Trophy", "Art Ross Trophy", "Lady Byng Trophy"],
            correct: 1
          }
        ]
      }
    ],

    "all-star": [
      {
        id: "nhl-all-star-1",
        title: "NHL All-Star Quiz 1",
        questions: [
          {
            question: "Which trophy is awarded to the NHL playoff MVP?",
            answers: ["Conn Smythe Trophy", "Hart Trophy", "Rocket Richard Trophy", "Presidents’ Trophy"],
            correct: 0
          },
          {
            question: "How many skaters per side are used in regular-season NHL overtime?",
            answers: ["2-on-2", "3-on-3", "4-on-4", "5-on-5"],
            correct: 1
          }
        ]
      }
    ]
  },

  nfl: {
    easy: [
      {
        id: "nfl-easy-1",
        title: "NFL Easy Quiz 1",
        questions: [
          {
            question: "How many points is a touchdown worth?",
            answers: [
              "3",
              "6",
              "7",
              "8"
            ],
            correct: 1
          },
          {
            question: "How many players does each NFL team have on the field?",
            answers: [
              "9",
              "10",
              "11",
              "12"
            ],
            correct: 2
          },
          {
            question: "What shape is an NFL field goal post opening?",
            answers: [
              "Square",
              "U-shaped",
              "V-shaped",
              "Round"
            ],
            correct: 1
          },
          {
            question: "How many quarters are in an NFL game?",
            answers: [
              "2",
              "3",
              "4",
              "5"
            ],
            correct: 2
          }
        ]
      }
    ],
    medium: [
      {
        id: "nfl-medium-1",
        title: "NFL Medium Quiz 1",
        questions: [
          {
            question: "How many yards is a first down worth?",
            answers: [
              "5",
              "10",
              "15",
              "20"
            ],
            correct: 1
          },
          {
            question: "What is the line called where the play begins?",
            answers: [
              "Start line",
              "Snap line",
              "Line of scrimmage",
              "Attack line"
            ],
            correct: 2
          },
          {
            question: "How many points is a field goal worth?",
            answers: [
              "1",
              "2",
              "3",
              "6"
            ],
            correct: 2
          },
          {
            question: "Which position usually throws the ball most often?",
            answers: [
              "Running back",
              "Quarterback",
              "Tight end",
              "Linebacker"
            ],
            correct: 1
          }
        ]
      }
    ],
    hard: [
      {
        id: "nfl-hard-1",
        title: "NFL Hard Quiz 1",
        questions: [
          {
            question: "How many points is a safety worth?",
            answers: [
              "1",
              "2",
              "3",
              "6"
            ],
            correct: 1
          },
          {
            question: "How many challenges does a team typically start with per game?",
            answers: [
              "1",
              "2",
              "3",
              "4"
            ],
            correct: 1
          },
          {
            question: "What happens on 4th down if a team chooses not to go for it?",
            answers: [
              "Automatic turnover",
              "Punt or kick is common",
              "Play stops permanently",
              "Clock resets"
            ],
            correct: 1
          },
          {
            question: "How long is a standard NFL quarter?",
            answers: [
              "10 minutes",
              "12 minutes",
              "15 minutes",
              "20 minutes"
            ],
            correct: 2
          }
        ]
      }
    ]
  },

  mlb: {
    easy: [
      {
        id: "mlb-easy-1",
        title: "MLB Easy Quiz 1",
        questions: [
          {
            question: "How many outs are in one half-inning?",
            answers: [
              "2",
              "3",
              "4",
              "6"
            ],
            correct: 1
          },
          {
            question: "How many bases are on a baseball diamond?",
            answers: [
              "3",
              "4",
              "5",
              "6"
            ],
            correct: 1
          },
          {
            question: "What is it called when a batter hits the ball out of the park in fair territory?",
            answers: [
              "Triple",
              "Grand slam only",
              "Home run",
              "Fly out"
            ],
            correct: 2
          },
          {
            question: "How many strikes usually make an out?",
            answers: [
              "2",
              "3",
              "4",
              "5"
            ],
            correct: 1
          }
        ]
      }
    ],
    medium: [
      {
        id: "mlb-medium-1",
        title: "MLB Medium Quiz 1",
        questions: [
          {
            question: "How many innings are in a standard MLB game?",
            answers: [
              "7",
              "8",
              "9",
              "10"
            ],
            correct: 2
          },
          {
            question: "What is it called when a pitcher records three strikeouts in one inning?",
            answers: [
              "Clean inning",
              "Perfect inning",
              "Triple strike inning",
              "There is no special universal name for that alone"
            ],
            correct: 3
          },
          {
            question: "What does RBI stand for?",
            answers: [
              "Run Batted In",
              "Runner Base Index",
              "Run Base In",
              "Batter Run In"
            ],
            correct: 0
          },
          {
            question: "What is the mound used for?",
            answers: [
              "Batting",
              "Pitching",
              "Catching",
              "Umpiring"
            ],
            correct: 1
          }
        ]
      }
    ],
    hard: [
      {
        id: "mlb-hard-1",
        title: "MLB Hard Quiz 1",
        questions: [
          {
            question: "How many balls result in a walk?",
            answers: [
              "2",
              "3",
              "4",
              "5"
            ],
            correct: 2
          },
          {
            question: "What is the infield fly rule designed to prevent?",
            answers: [
              "Pitch clock violations",
              "Easy double-play manipulation on a pop-up",
              "Catcher interference",
              "Stolen bases"
            ],
            correct: 1
          },
          {
            question: "What does ERA stand for?",
            answers: [
              "Earned Run Average",
              "Effective Run Allowance",
              "Earned Rotation Average",
              "Expected Run Average"
            ],
            correct: 0
          },
          {
            question: "How many strikes can a foul ball count toward after two strikes on most foul hits?",
            answers: [
              "It can still be strike three",
              "None beyond the second strike",
              "Always two more",
              "Depends on inning"
            ],
            correct: 1
          }
        ]
      }
    ]
  }
};