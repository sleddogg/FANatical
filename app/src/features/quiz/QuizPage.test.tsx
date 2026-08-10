import { act, fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { afterEach, describe, expect, it, vi } from "vitest";
import { appRoutes } from "../../app/routes";

function renderQuiz() {
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/quiz"] });
  return { router, ...render(<RouterProvider router={router} />) };
}

async function chooseNflRookie(user: ReturnType<typeof userEvent.setup>) {
  await user.click(screen.getByRole("button", { name: /Football/i }));
  await user.click(screen.getByRole("button", { name: /NFL Football/i }));
  await user.click(screen.getByRole("button", { name: /Rookie.*welcoming/i }));
}

function startNflRookieQuiz() {
  fireEvent.click(screen.getByRole("button", { name: /Football/i }));
  fireEvent.click(screen.getByRole("button", { name: /NFL Football/i }));
  fireEvent.click(screen.getByRole("button", { name: /Rookie.*welcoming/i }));
  fireEvent.click(screen.getByRole("button", { name: /Random Quiz/i }));
  fireEvent.click(screen.getByRole("button", { name: "Start Quiz" }));
}

function completeCurrentQuiz() {
  for (let question = 1; question <= 10; question += 1) {
    const answers = within(screen.getByRole("group", { name: "Answer choices" })).getAllByRole("button");
    const firstAnswer = answers.at(0);
    if (!firstAnswer) throw new Error("Expected four answer buttons");
    fireEvent.click(firstAnswer);
    fireEvent.click(screen.getByRole("button", { name: "Submit answer" }));
    act(() => vi.advanceTimersByTime(2000));
  }
}

afterEach(() => vi.useRealTimers());

describe("Quiz Hub", () => {
  it("renders the reference dashboard direction and shared navigation", () => {
    renderQuiz();

    expect(screen.getByRole("heading", { name: "Quiz", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Pick a Sport", level: 2 })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Back" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Add Quiz" })).toBeInTheDocument();
    const dashboard = screen.getByRole("region", { name: "Quiz dashboard" });
    expect(within(dashboard).getByText("5 days")).toBeInTheDocument();
    expect(within(dashboard).getByText("2 / 3")).toBeInTheDocument();
    expect(within(dashboard).getByText("12,450")).toBeInTheDocument();
    expect(within(dashboard).getByText("320")).toBeInTheDocument();
    expect(within(dashboard).getByText("42")).toBeInTheDocument();
    expect(within(dashboard).getByText("78%")).toBeInTheDocument();
    expect(screen.queryByText(/STEP \d OF 4/i)).not.toBeInTheDocument();
    expect(screen.getByRole("navigation", { name: "Application navigation" })).toBeInTheDocument();
    expect(screen.getByRole("link", { name: "Quiz" })).toHaveAttribute("aria-current", "page");
  });

  it("replaces each selection step and preserves choices when moving Back", async () => {
    const user = userEvent.setup();
    renderQuiz();

    await user.click(screen.getByRole("button", { name: /Football/i }));
    expect(screen.getByRole("heading", { name: "Quiz", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Pick a League" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football");
    expect(screen.queryByRole("heading", { name: "Pick a Sport" })).not.toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /NHL/i })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: /NFL Football/i })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: /NFL Football/i }));
    expect(screen.getByRole("heading", { name: "Pick a Difficulty" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football · NFL");
    await user.click(screen.getByRole("button", { name: "Back to leagues" }));
    expect(screen.getByRole("heading", { name: "Pick a League" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football");

    await user.click(screen.getByRole("button", { name: /NFL Football/i }));
    await user.click(screen.getByRole("button", { name: /Rookie.*welcoming/i }));
    expect(screen.getByRole("heading", { name: "Choose a Quiz" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football · NFL · Rookie");
    expect(screen.queryByText(/matching quizzes in the local catalog/i)).not.toBeInTheDocument();
  });

  it("selects a matching Random Quiz and launches the focused active state", async () => {
    const user = userEvent.setup();
    renderQuiz();
    await chooseNflRookie(user);

    await user.click(screen.getByRole("button", { name: /Random Quiz/i }));
    expect(screen.getByRole("heading", { name: "Sunday Moments: The Modern NFL" })).toBeInTheDocument();
    expect(screen.getByText("Football", { selector: "dd" })).toBeInTheDocument();
    expect(screen.getByText("NFL", { selector: "dd" })).toBeInTheDocument();
    expect(screen.getByText("Rookie", { selector: "dd" })).toBeInTheDocument();
    expect(screen.getByText("10", { selector: "dd" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Start Quiz" }));
    expect(screen.getByText("Question 1 of 10")).toBeInTheDocument();
    expect(screen.getByRole("timer", { name: "15 seconds remaining" })).toBeInTheDocument();
    expect(within(screen.getByRole("group", { name: "Answer choices" })).getAllByRole("button")).toHaveLength(4);
    expect(screen.getByRole("button", { name: "Submit answer" })).toBeDisabled();
    expect(document.body).toHaveClass("quiz-immersive-active");
    expect(screen.queryByRole("navigation", { name: "Application navigation" })).not.toBeInTheDocument();
  });

  it("allows answer changes before Submit, reveals feedback, and advances after timeout", () => {
    vi.useFakeTimers();
    renderQuiz();
    startNflRookieQuiz();

    fireEvent.click(screen.getByRole("button", { name: "3" }));
    expect(screen.getByRole("button", { name: "3" })).toHaveAttribute("data-state", "selected");
    fireEvent.click(screen.getByRole("button", { name: "7" }));
    expect(screen.getByRole("button", { name: "3" })).toHaveAttribute("data-state", "idle");
    fireEvent.click(screen.getByRole("button", { name: "Submit answer" }));
    expect(screen.getByRole("button", { name: "7" })).toHaveAttribute("data-state", "incorrect");
    expect(screen.getByRole("button", { name: /6Correct/i })).toHaveAttribute("data-state", "correct");
    expect(screen.getByText(/Not quite/i)).toBeInTheDocument();

    act(() => vi.advanceTimersByTime(2000));
    expect(screen.getByText("Question 2 of 10")).toBeInTheDocument();
    act(() => vi.advanceTimersByTime(15000));
    expect(screen.getByText(/Time expired/i)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /11Correct/i })).toHaveAttribute("data-state", "correct");
    act(() => vi.advanceTimersByTime(2000));
    expect(screen.getByText("Question 3 of 10")).toBeInTheDocument();
  });

  it("completes ten questions, shows Results, and chooses another eligible matching quiz", () => {
    vi.useFakeTimers();
    renderQuiz();
    startNflRookieQuiz();

    completeCurrentQuiz();

    expect(screen.getByText("10%")).toBeInTheDocument();
    expect(screen.getByText("1 correct answers out of 10")).toBeInTheDocument();
    expect(screen.getByText("Completed", { selector: "dd" })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: "Play Again" })).not.toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Next Quiz" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Change Difficulty" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Change League" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Quiz Hub" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Next Quiz" }));
    expect(screen.getByRole("heading", { name: "NFL Rules: First Down Fundamentals" })).toBeInTheDocument();
    expect(screen.queryByRole("heading", { name: "Sunday Moments: The Modern NFL" })).not.toBeInTheDocument();
  });

  it("returns from Results to the requested selection level with the right context", () => {
    vi.useFakeTimers();
    const firstRun = renderQuiz();
    startNflRookieQuiz();
    completeCurrentQuiz();

    fireEvent.click(screen.getByRole("button", { name: "Change Difficulty" }));
    expect(screen.getByRole("heading", { name: "Quiz", level: 1 })).toBeInTheDocument();
    expect(screen.getByRole("heading", { name: "Pick a Difficulty" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football · NFL");
    firstRun.unmount();

    const secondRun = renderQuiz();
    startNflRookieQuiz();
    completeCurrentQuiz();
    fireEvent.click(screen.getByRole("button", { name: "Change League" }));
    expect(screen.getByRole("heading", { name: "Pick a League" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football");
    secondRun.unmount();

    renderQuiz();
    startNflRookieQuiz();
    completeCurrentQuiz();
    fireEvent.click(screen.getByRole("button", { name: "Quiz Hub" }));
    expect(screen.getByRole("heading", { name: "Pick a Sport" })).toBeInTheDocument();
    expect(screen.queryByLabelText("Current quiz context")).not.toBeInTheDocument();
  }, 10000);

  it("browses matching categories and chooses a canonical quiz card", async () => {
    const user = userEvent.setup();
    renderQuiz();
    await chooseNflRookie(user);

    await user.click(screen.getByRole("button", { name: /Browse Category/i }));
    expect(screen.getByRole("heading", { name: "Choose a Topic" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Rules" }));
    expect(screen.getByRole("button", { name: /NFL Rules: First Down Fundamentals/i })).toBeInTheDocument();
    expect(screen.queryByRole("button", { name: /NFL Legends/i })).not.toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: /NFL Rules: First Down Fundamentals/i }));
    expect(screen.getByRole("heading", { name: "NFL Rules: First Down Fundamentals" })).toBeInTheDocument();
    await user.click(screen.getByRole("button", { name: "Back to quiz categories" }));
    expect(screen.getByRole("heading", { name: "Choose a Topic" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Rules" })).toHaveAttribute("aria-pressed", "true");
  });

  it("shows only completed quizzes past the mock retake cooldown", async () => {
    const user = userEvent.setup();
    renderQuiz();
    await chooseNflRookie(user);

    await user.click(screen.getByRole("button", { name: /Retake Quiz/i }));
    expect(screen.getByRole("heading", { name: "Eligible Retakes" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: /NFL Rules: First Down Fundamentals/i })).toHaveTextContent("Last score 100% · completed 22 days ago");
    expect(screen.queryByRole("button", { name: /NFL Legends/i })).not.toBeInTheDocument();
  });

  it("shows a clear empty state for an unmatched catalog selection", async () => {
    const user = userEvent.setup();
    renderQuiz();

    await user.click(screen.getByRole("button", { name: /Hockey/i }));
    await user.click(screen.getByRole("button", { name: /NHL Hockey/i }));
    await user.click(screen.getByRole("button", { name: /All-Star.*sharpest/i }));
    await user.click(screen.getByRole("button", { name: /Random Quiz/i }));
    expect(screen.getByRole("heading", { name: "No quizzes available for this selection" })).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Change difficulty" })).toBeInTheDocument();
  });

  it("opens the real Create Quiz identity stage from Add Quiz", async () => {
    const user = userEvent.setup();
    renderQuiz();

    await user.click(screen.getByRole("button", { name: "Add Quiz" }));
    const dialog = screen.getByRole("dialog", { name: "Quiz Identity" });
    expect(within(dialog).getByLabelText("Sport")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("League")).toBeDisabled();
    expect(within(dialog).getByLabelText("Difficulty")).toBeInTheDocument();
    expect(within(dialog).getByLabelText("Topic / category")).toBeInTheDocument();
    expect(within(dialog).getByRole("button", { name: "Continue to details" })).toBeDisabled();
  });

  it("returns from an untouched Create Quiz flow without resetting Quiz selection", async () => {
    const user = userEvent.setup();
    renderQuiz();
    await user.click(screen.getByRole("button", { name: /Football/i }));
    expect(screen.getByRole("heading", { name: "Pick a League" })).toBeInTheDocument();

    await user.click(screen.getByRole("button", { name: "Add Quiz" }));
    await user.click(screen.getByRole("button", { name: "Exit Create Quiz" }));

    expect(screen.getByRole("heading", { name: "Pick a League" })).toBeInTheDocument();
    expect(screen.getByLabelText("Current quiz context")).toHaveTextContent("Football");
  });
});
