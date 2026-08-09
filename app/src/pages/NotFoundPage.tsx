import { Link } from "react-router-dom";

export function NotFoundPage() {
  return (
    <main id="main-content" className="content-container not-found" tabIndex={-1}>
      <span className="eyebrow">404</span>
      <h1>That page is out of bounds.</h1>
      <p>The route does not exist in FANatical.</p>
      <Link className="button button--primary" to="/">
        Return home
      </Link>
    </main>
  );
}
