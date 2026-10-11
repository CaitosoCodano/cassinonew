import { describe, expect, it } from "vitest";
import { ApiError, apiErrorMessage } from "./api";

// A player who registers with an address that already exists, or a password
// the validator rejects, is told nothing useful unless these details reach the
// screen. Every form in the app routes its failures through apiErrorMessage, so
// this is the single place where a server explanation is either kept or lost.
describe("apiErrorMessage", () => {
  it("returns the message when there are no details", () => {
    expect(apiErrorMessage(new ApiError(422, "registration_failed", "We could not create your account.")))
      .toBe("We could not create your account.");
  });

  it("includes a single validation detail", () => {
    expect(
      apiErrorMessage(new ApiError(422, "validation_failed", "The request could not be processed.",
        ["Email has already been taken"])),
    ).toBe("The request could not be processed. (Email has already been taken)");
  });

  it("includes every detail so a form can be fixed in one pass", () => {
    expect(
      apiErrorMessage(new ApiError(422, "registration_failed", "We could not create your account.",
        ["Email has already been taken", "Password is too short"])),
    ).toBe("We could not create your account. (Email has already been taken; Password is too short)");
  });

  it("flattens field-keyed details", () => {
    expect(
      apiErrorMessage(new ApiError(422, "validation_failed", "The request could not be processed.",
        { email: ["is invalid"], password: ["is too short"] })),
    ).toBe("The request could not be processed. (email is invalid; password is too short)");
  });

  it("handles a string detail", () => {
    expect(apiErrorMessage(new ApiError(403, "forbidden", "You do not have permission.", "game:spin")))
      .toBe("You do not have permission. (game:spin)");
  });

  it("ignores an empty details payload rather than appending empty brackets", () => {
    expect(apiErrorMessage(new ApiError(422, "registration_failed", "Nope.", []))).toBe("Nope.");
    expect(apiErrorMessage(new ApiError(422, "registration_failed", "Nope.", null))).toBe("Nope.");
  });

  it("passes non-API errors straight through", () => {
    expect(apiErrorMessage(new Error("network down"))).toBe("network down");
  });
});