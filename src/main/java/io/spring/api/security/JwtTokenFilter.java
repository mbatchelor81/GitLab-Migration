package io.spring.api.security;

import io.spring.core.service.JwtService;
import io.spring.core.user.User;
import io.spring.core.user.UserRepository;
import java.io.IOException;
import java.util.Collections;
import java.util.Optional;
import javax.servlet.FilterChain;
import javax.servlet.ServletException;
import javax.servlet.http.HttpServletRequest;
import javax.servlet.http.HttpServletResponse;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.context.SecurityContextHolder;
import org.springframework.security.web.authentication.WebAuthenticationDetailsSource;
import org.springframework.web.filter.OncePerRequestFilter;

public class JwtTokenFilter extends OncePerRequestFilter {
  private static final Logger LOG = LoggerFactory.getLogger(JwtTokenFilter.class);
  private static final String AUTH_HEADER = "Authorization";
  private static final String TOKEN_PREFIX = "Token ";

  @Autowired private UserRepository userRepository;
  @Autowired private JwtService jwtService;

  @Override
  protected void doFilterInternal(
      HttpServletRequest request, HttpServletResponse response, FilterChain filterChain)
      throws ServletException, IOException {
    String header = request.getHeader(AUTH_HEADER);
    if (header == null || !header.startsWith(TOKEN_PREFIX)) {
      filterChain.doFilter(request, response);
      return;
    }

    String token = header.substring(TOKEN_PREFIX.length());
    try {
      Optional<String> subOptional = jwtService.getSubFromToken(token);
      if (subOptional.isPresent()) {
        Optional<User> userOptional = userRepository.findById(subOptional.get());
        if (userOptional.isPresent()) {
          UsernamePasswordAuthenticationToken authToken =
              new UsernamePasswordAuthenticationToken(
                  userOptional.get(), null, Collections.emptyList());
          authToken.setDetails(new WebAuthenticationDetailsSource().buildDetails(request));
          SecurityContextHolder.getContext().setAuthentication(authToken);
        }
      }
    } catch (Exception e) {
      LOG.warn("JWT authentication failed for request {}: {}", request.getRequestURI(), e.getMessage());
      SecurityContextHolder.clearContext();
    }
    filterChain.doFilter(request, response);
  }
}
