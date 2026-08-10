import { fireEvent, render, screen, within } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { createMemoryRouter, RouterProvider } from "react-router-dom";
import { describe, expect, it, vi } from "vitest";
import { appRoutes } from "../../app/routes";
import { CreateQuizFlow } from "./CreateQuizFlow";

function renderQuizPage() {
  const router = createMemoryRouter(appRoutes, { initialEntries: ["/quiz"] });
  return render(<RouterProvider router={router} />);
}

function fillIdentityAndDetails() {
  fireEvent.change(screen.getByLabelText("Sport"), { target: { value: "Football" } });
  fireEvent.change(screen.getByLabelText("League"), { target: { value: "NFL" } });
  fireEvent.change(screen.getByLabelText("Difficulty"), { target: { value: "Rookie" } });
  fireEvent.change(screen.getByLabelText("Topic / category"), { target: { value: "Rules" } });
  fireEvent.change(screen.getByLabelText("Optional tags"), { target: { value: "rules, NFL, rules" } });
  fireEvent.click(screen.getByRole("button", { name: "Continue to details" }));
  fireEvent.change(screen.getByLabelText("Quiz title"), { target: { value: "Build Your NFL Foundation" } });
  fireEvent.change(screen.getByLabelText("Short description"), { target: { value: "Ten approachable questions about NFL rules and scoring." } });
}

function fillAllQuestions() {
  for (let question = 1; question <= 10; question += 1) {
    fireEvent.change(screen.getByLabelText("Question text"), { target: { value: `Authored question ${question}?` } });
    fireEvent.change(screen.getByLabelText("Answer A"), { target: { value: `Answer ${question}A` } });
    fireEvent.change(screen.getByLabelText("Answer B"), { target: { value: `Answer ${question}B` } });
    fireEvent.change(screen.getByLabelText("Answer C"), { target: { value: `Answer ${question}C` } });
    fireEvent.change(screen.getByLabelText("Answer D"), { target: { value: `Answer ${question}D` } });
    fireEvent.click(screen.getByLabelText("Mark answer B as correct"));
    if (question < 10) fireEvent.click(screen.getByRole("button", { name: "Next question" }));
  }
}

describe("Create Quiz", () => {
  it("preserves entered identity and details while moving backward", async () => {
    const user = userEvent.setup();
    renderQuizPage();
    await user.click(screen.getByRole("button", { name: "Add Quiz" }));

    fillIdentityAndDetails();
    fireEvent.click(screen.getByRole("button", { name: "Back one creation stage" }));
    expect(screen.getByLabelText("Sport")).toHaveValue("Football");
    expect(screen.getByLabelText("League")).toHaveValue("NFL");
    expect(screen.getByLabelText("Difficulty")).toHaveValue("Rookie");
    expect(screen.getByLabelText("Topic / category")).toHaveValue("Rules");
    expect(screen.getByLabelText("Optional tags")).toHaveValue("rules, NFL, rules");

    fireEvent.click(screen.getByRole("button", { name: "Continue to details" }));
    expect(screen.getByLabelText("Quiz title")).toHaveValue("Build Your NFL Foundation");
    expect(screen.getByLabelText("Short description")).toHaveValue("Ten approachable questions about NFL rules and scoring.");
  });

  it("guards substantial draft content before leaving", async () => {
    const user = userEvent.setup();
    const firstRender = renderQuizPage();
    await user.click(screen.getByRole("button", { name: "Add Quiz" }));
    fireEvent.click(screen.getByRole("button", { name: "Exit Create Quiz" }));
    expect(screen.queryByRole("dialog", { name: "Quiz Identity" })).not.toBeInTheDocument();
    firstRender.unmount();

    renderQuizPage();
    await user.click(screen.getByRole("button", { name: "Add Quiz" }));
    fireEvent.change(screen.getByLabelText("Sport"), { target: { value: "Football" } });
    fireEvent.click(screen.getByRole("button", { name: "Exit Create Quiz" }));
    const confirmation = screen.getByRole("alertdialog", { name: "Leave Create Quiz?" });
    fireEvent.click(within(confirmation).getByRole("button", { name: "Keep Creating" }));
    expect(screen.getByRole("dialog", { name: "Quiz Identity" })).toBeInTheDocument();
    fireEvent.click(screen.getByRole("button", { name: "Exit Create Quiz" }));
    fireEvent.click(screen.getByRole("button", { name: "Leave Create Quiz" }));
    expect(screen.queryByRole("dialog", { name: "Quiz Identity" })).not.toBeInTheDocument();
  });

  it("authors exactly ten complete questions, reviews edits, and saves a pending submission", () => {
    const onSubmit = vi.fn();
    render(<CreateQuizFlow onClose={vi.fn()} onSubmit={onSubmit} />);
    fillIdentityAndDetails();
    fireEvent.click(screen.getByRole("button", { name: "Write 10 questions" }));

    expect(screen.getByRole("button", { name: "Review Quiz" })).toBeDisabled();
    fillAllQuestions();
    expect(screen.getAllByRole("button", { name: /Question \d+ complete$/ })).toHaveLength(10);
    expect(screen.getByRole("button", { name: "Review Quiz" })).toBeEnabled();
    fireEvent.click(screen.getByRole("button", { name: "Review Quiz" }));

    expect(screen.getByRole("heading", { name: "Review Quiz" })).toBeInTheDocument();
    expect(screen.getAllByText("Correct answer")).toHaveLength(10);
    fireEvent.click(screen.getByRole("button", { name: "Edit question 5" }));
    expect(screen.getByText("Question 5 of 10")).toBeInTheDocument();
    fireEvent.change(screen.getByLabelText("Question text"), { target: { value: "Edited authored question 5?" } });
    fireEvent.click(screen.getByRole("button", { name: "Return to Review" }));
    expect(screen.getByRole("heading", { name: "Edited authored question 5?" })).toBeInTheDocument();

    fireEvent.click(screen.getByRole("button", { name: "Submit Quiz" }));
    expect(onSubmit).toHaveBeenCalledTimes(1);
    expect(onSubmit).toHaveBeenCalledWith(expect.objectContaining({
      sport: "Football",
      league: "NFL",
      submittedDifficulty: "Rookie",
      topic: "Rules",
      tags: ["rules", "NFL"],
      questionCount: 10,
      approvalStatus: "Pending Review",
    }));
    const submission = onSubmit.mock.calls[0]?.[0];
    expect(submission?.questions).toHaveLength(10);
    expect(submission?.questions[4]?.prompt).toBe("Edited authored question 5?");
    expect(submission?.questions.every((question: { answers: readonly string[]; correctAnswerIndex: number }) => question.answers.length === 4 && question.correctAnswerIndex === 1)).toBe(true);
    expect(screen.getByRole("heading", { name: "Quiz Submitted" })).toBeInTheDocument();
    expect(screen.getByText(/submitted for review/i)).toBeInTheDocument();
    expect(screen.getByText("Pending Review")).toBeInTheDocument();
  });
});
