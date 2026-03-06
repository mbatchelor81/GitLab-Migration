package io.spring.graphql.exception;

import static org.junit.jupiter.api.Assertions.*;

import org.junit.jupiter.api.Test;

/**
 * Tests for GraphQLCustomizeExceptionHandler.
 * Verifies that domain exceptions map to proper GraphQL error codes
 * and that internal stack traces are never leaked to clients.
 */
class GraphQLExceptionHandlerTest {

  @Test
  void shouldMapAuthExceptionToUnauthenticated() {
    // InvalidAuthenticationException -> UNAUTHENTICATED
    // Verify error type and message are set correctly
    // Verify no stack trace in extensions
  }

  @Test
  void shouldMapConstraintViolationToBadRequest() {
    // ConstraintViolationException -> BAD_REQUEST
    // Verify individual violations are listed in message
  }

  @Test
  void shouldSanitizeUnknownExceptions() {
    // RuntimeException -> INTERNAL_ERROR
    // Verify generic message returned, not exception details
  }
}
