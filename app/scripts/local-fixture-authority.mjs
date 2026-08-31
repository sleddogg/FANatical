function asError(value) {
  return value instanceof Error ? value : new Error(String(value));
}

export async function withTemporaryFixtureAuthority({
  removeAuthority,
  grantAuthority,
  provision,
  cleanupOperations = [],
}) {
  if (
    typeof removeAuthority !== "function"
    || typeof grantAuthority !== "function"
    || typeof provision !== "function"
    || !Array.isArray(cleanupOperations)
    || cleanupOperations.some((operation) => typeof operation !== "function")
  ) {
    throw new Error("Temporary fixture authority lifecycle callbacks are incomplete.");
  }

  let result;
  const errors = [];
  try {
    await removeAuthority("stale");
    await grantAuthority();
    result = await provision();
  } catch (error) {
    errors.push(asError(error));
  }

  for (const operation of cleanupOperations) {
    try {
      await operation();
    } catch (error) {
      errors.push(asError(error));
    }
  }

  try {
    await removeAuthority("final");
  } catch (error) {
    errors.push(asError(error));
  }

  if (errors.length === 1) throw errors[0];
  if (errors.length > 1) {
    throw new AggregateError(errors, "Local fixture provisioning or cleanup failed.");
  }
  return result;
}
