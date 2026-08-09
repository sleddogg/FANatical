/* QUIZ LANDING PAGE STATE */
document.addEventListener("DOMContentLoaded", () => {
  const category = localStorage.getItem("quizCategory") || "NHL";
  const difficulty = localStorage.getItem("quizDifficulty") || "Rookie";

  currentCategory = normalizeCategory(category);
  currentDifficulty = normalizeDifficulty(difficulty);

  updateQuizLandingCard(category, difficulty);

  document.querySelector(".quiz-landing-card").classList.add("hidden");
  document.querySelector(".back-arrow-btn").classList.add("hidden");
  document.getElementById("quiz-container").classList.remove("hidden");

  renderPreQuizOptions();
});

/* TEMP AVERAGE SCORE DATA */
function getAverageScore(category, difficulty) {
  const normalizedDifficulty = normalizeDifficulty(difficulty);

  const averageScores = {
    rookie: 82,
    grinder: 68,
    "league-average": 57,
    star: 46,
    "all-star": 34
  };

  return averageScores[normalizedDifficulty] || 60;
}

function updateQuizLandingCard(category, difficulty) {
  const landingCategory = document.getElementById("landingCategory");
  const landingDifficulty = document.getElementById("landingDifficulty");
  const landingAverageScore = document.getElementById("landingAverageScore");

  if (landingCategory) landingCategory.textContent = category;
  if (landingDifficulty) landingDifficulty.textContent = difficulty;
  if (landingAverageScore) landingAverageScore.textContent = getAverageScore(category, difficulty) + "%";
}

/* START SELECTED QUIZ */
function startQuiz() {
  document.querySelector(".quiz-landing-card").classList.add("hidden");
  document.querySelector(".back-arrow-btn").classList.add("hidden");
  document.getElementById("quiz-container").classList.remove("hidden");

  loadQuiz(currentCategory, currentDifficulty, 0);
}

/* QUIZ STATE */
const urlParams = new URLSearchParams(window.location.search);

let currentCategory = normalizeCategory(urlParams.get("category") || localStorage.getItem("quizCategory") || "NHL");
let currentDifficulty = normalizeDifficulty(localStorage.getItem("quizDifficulty") || "Rookie");
let currentQuizIndex = 0;

let currentQuiz = null;
let currentQuestion = 0;
let score = 0;
let answerLocked = false;
let countdown = null;

const quizContainer = document.getElementById("quiz-container");

/* QUIZ VALUE NORMALIZERS */
function normalizeCategory(category) {
  return String(category).toLowerCase();
}

function normalizeDifficulty(difficulty) {
  return String(difficulty)
    .toLowerCase()
    .trim()
    .replace(/\s+/g, "-");
}

function renderQuizHub() {
  quizContainer.innerHTML = `
    <div class="quiz-hub-card">
      <div class="quiz-hub-header">
        <h2>Train your brain</h2>
      </div>

      <div class="quiz-hub-stats">
        <div>
          <strong>12</strong>
          <span>Quizzes completed</span>
        </div>
        <div>
          <strong>74%</strong>
          <span>Average score</span>
        </div>
        <div>
          <strong>120</strong>
          <span>Total points</span>
        </div>
      </div>

      <div class="hub-section-title">Choose Category</div>

      <div class="hub-category-grid">
        <button class="hub-category-btn" data-category="nhl">NHL</button>
        <button class="hub-category-btn" data-category="nfl">NFL</button>
        <button class="hub-category-btn" data-category="mlb">MLB</button>
      </div>

      <div class="hub-actions">
        <button class="result-btn" id="start-quiz-btn">Start Quiz</button>
        <button class="result-btn" id="create-quiz-btn">Create a Quiz</button>
      </div>
    </div>
  `;

  document.querySelectorAll(".hub-category-btn").forEach(button => {
    button.addEventListener("click", () => {
      currentCategory = button.dataset.category;

      document.querySelectorAll(".hub-category-btn").forEach(btn => {
        btn.classList.remove("selected");
      });

      button.classList.add("selected");
    });
  });

  document.querySelector(`[data-category="${currentCategory}"]`).classList.add("selected");

  document.getElementById("start-quiz-btn").addEventListener("click", () => {
    renderPreQuizOptions();
  });

  document.getElementById("create-quiz-btn").addEventListener("click", createQuiz);
}

function renderQuestion() {
  answerLocked = false;

  const currentQuestionData = currentQuiz.questions[currentQuestion];

  quizContainer.innerHTML = `
    <div class="quiz-card">
      <div class="quiz-meta-row">
        <div class="quiz-tag">${currentCategory.toUpperCase()}</div>
        <div class="quiz-tag">${capitalize(currentDifficulty)}</div>
      </div>

      <div class="quiz-progress">
        ${currentQuiz.title} • Question ${currentQuestion + 1} of ${currentQuiz.questions.length}
      </div>

      <h2 class="quiz-question">${currentQuestionData.question}</h2>

	<div class="quiz-timer" id="quiz-timer">3</div>

      <div class="quiz-answers">
        ${currentQuestionData.answers.map((answer, index) => `
          <button class="answer-btn" data-index="${index}">
            ${answer}
          </button>
        `).join("")}
      </div>

      <div class="quiz-feedback" id="quiz-feedback"></div>
    </div>
  `;

  const answerButtons = document.querySelectorAll(".answer-btn");
  answerButtons.forEach(button => {
    button.addEventListener("click", handleAnswerClick);
  });
  let timeLeft = 3;
  const timerElement = document.getElementById("quiz-timer");

 if (countdown) {
  clearInterval(countdown);
}

countdown = setInterval(() => {
    timeLeft--;
    timerElement.textContent = timeLeft;

    if (timeLeft <= 0) {
      clearInterval(countdown);

      if (!answerLocked) {
        answerLocked = true;
	clearInterval(countdown);

        const correctIndex = currentQuiz.questions[currentQuestion].correct;
        const allButtons = document.querySelectorAll(".answer-btn");

        allButtons.forEach(button => {
          button.disabled = true;
        });

        allButtons[correctIndex].classList.add("correct");

        const feedback = document.getElementById("quiz-feedback");
        feedback.textContent = "Time’s up";
        feedback.className = "quiz-feedback incorrect-text";

        setTimeout(() => {
          currentQuestion++;

          if (currentQuestion < currentQuiz.questions.length) {
            renderQuestion();
          } else {
            renderResults();
          }
        }, 1000);
      }
    }
  }, 1000);
}

function handleAnswerClick(event) {
  if (answerLocked) return;

  answerLocked = true;

  const selectedButton = event.target;
  const selectedIndex = Number(selectedButton.dataset.index);
  const correctIndex = currentQuiz.questions[currentQuestion].correct;
  const allButtons = document.querySelectorAll(".answer-btn");
  const feedback = document.getElementById("quiz-feedback");

  allButtons.forEach(button => {
    button.disabled = true;
  });

  if (selectedIndex === correctIndex) {
    score++;
    selectedButton.classList.add("correct");
    feedback.textContent = "Correct";
    feedback.className = "quiz-feedback correct-text";
  } else {
    selectedButton.classList.add("incorrect");
    allButtons[correctIndex].classList.add("correct");
    feedback.textContent = "Incorrect";
    feedback.className = "quiz-feedback incorrect-text";
  }

  setTimeout(() => {
    currentQuestion++;

    if (currentQuestion < currentQuiz.questions.length) {
      renderQuestion();
    } else {
      renderResults();
    }
  }, 1000);
}

function renderResults() {
  const percentage = Math.round((score / currentQuiz.questions.length) * 100);
  const quizList = quizzes[currentCategory][currentDifficulty];
  const hasNextQuiz = currentQuizIndex + 1 < quizList.length;

  let message = "";

  if (score === currentQuiz.questions.length) {
    message = "Perfect. You know your stuff.";
  } else if (percentage >= 75) {
    message = "Strong round.";
  } else if (percentage >= 50) {
    message = "Not bad. Mid-table form.";
  } else if (percentage >= 25) {
    message = "Rough showing.";
  } else {
    message = "Disaster class.";
  }

  quizContainer.innerHTML = `
    <div class="quiz-card results-card">
      <div class="quiz-meta-row">
        <div class="quiz-tag">${currentCategory.toUpperCase()}</div>
        <div class="quiz-tag">${capitalize(currentDifficulty)}</div>
      </div>

      <div class="quiz-progress">Quiz Complete</div>
      <h2 class="quiz-question">Final Score: ${score}/${currentQuiz.questions.length}</h2>
      <div class="quiz-score-percent">${percentage}%</div>
      <div class="quiz-feedback results-message">${message}</div>

      <div class="results-actions">
        <button class="result-btn" id="next-quiz-btn" ${hasNextQuiz ? "" : "disabled"}>
          ${hasNextQuiz ? "Next Quiz" : "Next Quiz (No more available)"}
        </button>
        <button class="result-btn" id="change-category-btn">Change Category</button>
        <button class="result-btn" id="change-difficulty-btn">Change Difficulty</button>
        <button class="result-btn" id="back-hub-btn">Back to Hub</button>
      </div>
    </div>
  `;

  if (hasNextQuiz) {
    document.getElementById("next-quiz-btn").addEventListener("click", handleNextQuiz);
  }

  document.getElementById("change-category-btn").addEventListener("click", openCategoryPanel);
  document.getElementById("change-difficulty-btn").addEventListener("click", openDifficultyPanelOnly);
  document.getElementById("back-hub-btn").addEventListener("click", backToHub);
}

function handleNextQuiz() {
  const nextIndex = currentQuizIndex + 1;
  const quizList = quizzes[currentCategory][currentDifficulty];

  if (nextIndex < quizList.length) {
    loadQuiz(currentCategory, currentDifficulty, nextIndex);
  } else {
    showNoMorePanel();
  }
}

function openCategoryPanel() {
  if (countdown) {
    clearInterval(countdown);
  }

  quizContainer.innerHTML = `
    <div class="quiz-card">
      <div class="quiz-progress">Choose Category</div>

      <div class="panel-options">
        <button class="panel-btn category-option" data-category="nhl">NHL</button>
        <button class="panel-btn category-option" data-category="nfl">NFL</button>
        <button class="panel-btn category-option" data-category="mlb">MLB</button>
      </div>
    </div>
  `;

  const categoryButtons = document.querySelectorAll(".category-option");

  categoryButtons.forEach(button => {
    button.addEventListener("click", () => {
      currentCategory = button.dataset.category;
      openDifficultyPanelOnly();
    });
  });
}

function openDifficultyPanelAfterCategoryChange() {
  hideAllPanels();
  document.getElementById("difficulty-panel").classList.remove("hidden");
  preselectDifficulty(currentDifficulty);

  const confirmBtn = document.getElementById("confirm-difficulty-btn");
  confirmBtn.onclick = () => {
    const selectedDifficulty = getSelectedDifficulty();
    currentDifficulty = selectedDifficulty;

    if (hasQuizzes(currentCategory, currentDifficulty)) {
      loadQuiz(currentCategory, currentDifficulty, 0);
    } else {
      showNoMorePanel();
    }
  };
}

function openDifficultyPanelOnly() {
  if (countdown) {
    clearInterval(countdown);
  }

  quizContainer.innerHTML = `
    <div class="quiz-card">
      <div class="quiz-meta-row">
        <div class="quiz-tag">${currentCategory.toUpperCase()}</div>
      </div>

      <div class="quiz-progress">Choose Difficulty</div>

      <div class="difficulty-options">
        <label class="difficulty-option">
          <input type="radio" name="difficulty" value="rookie">
          Rookie
        </label>
        <label class="difficulty-option">
          <input type="radio" name="difficulty" value="grinder">
          Grinder
        </label>
        <label class="difficulty-option">
          <input type="radio" name="difficulty" value="league-average">
          League Average
        </label>
        <label class="difficulty-option">
          <input type="radio" name="difficulty" value="star">
          Star
        </label>
        <label class="difficulty-option">
          <input type="radio" name="difficulty" value="all-star">
          All-Star
        </label>
      </div>

      <button class="result-btn panel-continue-btn" id="confirm-difficulty-btn">Continue</button>
    </div>
  `;

  preselectDifficulty(currentDifficulty);

  document.getElementById("confirm-difficulty-btn").onclick = () => {
    const selectedDifficulty = getSelectedDifficulty();
    currentDifficulty = selectedDifficulty;
    renderPreQuizOptions();
  };
}

function renderPreQuizOptions() {
  const hasQuizLane = hasQuizzes(currentCategory, currentDifficulty);

  quizContainer.innerHTML = `
    <div class="quiz-card">
      <div class="quiz-meta-row">
        <div class="quiz-tag">${currentCategory.toUpperCase()}</div>
        <div class="quiz-tag">${capitalize(currentDifficulty)}</div>
      </div>

      <div class="quiz-progress">Choose Quiz</div>

      <div class="results-actions">
        <button class="result-btn" id="pre-random-quiz-btn" ${hasQuizLane ? "" : "disabled"}>Random Quiz</button>
        <button class="result-btn" id="pre-browse-category-btn">Browse Category</button>
        <button class="result-btn" id="pre-retake-quiz-btn" ${hasQuizLane ? "" : "disabled"}>Retake Quiz</button>
        <button class="result-btn" id="pre-create-quiz-btn">Create Quiz</button>
      </div>
    </div>
  `;

  if (hasQuizLane) {
        document.getElementById("pre-random-quiz-btn").onclick = () => {
      const displayCategory = currentCategory.toUpperCase();
      const displayDifficulty = currentDifficulty
        .split("-")
        .map(capitalize)
        .join("-");

      updateQuizLandingCard(displayCategory, displayDifficulty);

      quizContainer.classList.add("hidden");
      document.querySelector(".quiz-landing-card").classList.remove("hidden");
      document.querySelector(".back-arrow-btn").classList.remove("hidden");
    };

    document.getElementById("pre-retake-quiz-btn").onclick = () => loadQuiz(currentCategory, currentDifficulty, 0);
  }

  document.getElementById("pre-browse-category-btn").onclick = openCategoryPanel;
  document.getElementById("pre-create-quiz-btn").onclick = createQuiz;
}

function showNoMorePanel() {
  hideAllPanels();
  document.getElementById("no-more-panel").classList.remove("hidden");

  document.getElementById("fallback-change-category-btn").onclick = openCategoryPanel;
  document.getElementById("fallback-change-difficulty-btn").onclick = openDifficultyPanelOnly;
  document.getElementById("fallback-back-hub-btn").onclick = backToHub;
  document.getElementById("fallback-create-quiz-btn").onclick = createQuiz;
}

function hideAllPanels() {
  const panels = document.querySelectorAll(".inline-panel");
  panels.forEach(panel => panel.classList.add("hidden"));
}

function preselectDifficulty(difficulty) {
  const difficultyInput = document.querySelector(`input[name="difficulty"][value="${difficulty}"]`);
  if (difficultyInput) {
    difficultyInput.checked = true;
  }
}

function getSelectedDifficulty() {
  const selected = document.querySelector('input[name="difficulty"]:checked');
  return selected ? selected.value : "easy";
}

function hasQuizzes(category, difficulty) {
  return (
    quizzes[category] &&
    quizzes[category][difficulty] &&
    quizzes[category][difficulty].length > 0
  );
}

function loadQuiz(category, difficulty, quizIndex) {
  currentCategory = category;
  currentDifficulty = difficulty;
  currentQuizIndex = quizIndex;
  currentQuiz = quizzes[currentCategory][currentDifficulty][currentQuizIndex];
  currentQuestion = 0;
  score = 0;
  answerLocked = false;

  renderQuestion();
}

/* =========================
   QUIZ HUB NAVIGATION
   Sends user back to the JS-rendered Quiz Hub screen
   ========================= */

function backToHub() {
  if (countdown) {
    clearInterval(countdown);
  }

  window.location.href = "quiz-hub.html";
}

function createQuiz() {
  alert("Create a Quiz page coming next.");
}

function capitalize(word) {
  return word.charAt(0).toUpperCase() + word.slice(1);
}
