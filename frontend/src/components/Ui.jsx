export function Loader({ text = "Loading..." }) {
  return (
    <div className="state-card">
      <span className="spinner" />
      <strong>{text}</strong>
      <p>Please wait a moment.</p>
    </div>
  );
}

export function ErrorState({ message, onRetry }) {
  return (
    <div className="state-card state-error">
      <span className="state-icon">!</span>
      <strong>Something went wrong</strong>
      <p>{message}</p>
      {onRetry && <button className="btn btn-dark" onClick={onRetry}>Try Again</button>}
    </div>
  );
}

export function EmptyState({ icon = "✦", title, text, action }) {
  return (
    <div className="empty-state">
      <span className="empty-icon">{icon}</span>
      <h3>{title}</h3>
      <p>{text}</p>
      {action}
    </div>
  );
}

export function Badge({ children, tone = "green" }) {
  return <span className={`badge badge-${tone}`}>{children}</span>;
}
