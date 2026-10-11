import { Link } from "react-router-dom";
import { Button, Panel } from "../components/ui";
import { PageHeader } from "../components/ui";

export default function NotFoundPage() {
  return (
    <div>
      <PageHeader
        title="Page not found"
        eyebrow="Error"
        lead="The page you are looking for doesn’t exist or was moved."
      />
      <Panel>
        <p className="muted">Return to the homepage or browse the games catalogue.</p>
        <div className="row">
          <Link to="/" className="btn btn--primary">
            Home
          </Link>
          <Link to="/games" className="btn">
            Games
          </Link>
        </div>
      </Panel>
    </div>
  );
}