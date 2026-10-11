import type { ButtonHTMLAttributes, InputHTMLAttributes, ReactNode, SelectHTMLAttributes, TextareaHTMLAttributes } from "react";

type ButtonVariant = "default" | "primary" | "ghost" | "danger";
type ButtonSize = "md" | "sm";

export function Button({
  variant = "default",
  size = "md",
  loading = false,
  className = "",
  children,
  disabled,
  ...rest
}: ButtonHTMLAttributes<HTMLButtonElement> & {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
}) {
  const variantClass: Record<ButtonVariant, string> = {
    default: "",
    primary: "btn--primary",
    ghost: "btn--ghost",
    danger: "btn--danger",
  };
  const classes = ["btn", variantClass[variant], size === "sm" ? "btn--sm" : "", className]
    .filter(Boolean)
    .join(" ");
  return (
    <button className={classes} disabled={disabled || loading} {...rest}>
      {loading ? <span className="spinner" aria-hidden="true" /> : null}
      {children}
    </button>
  );
}

export function Field({
  label,
  hint,
  error,
  children,
  htmlFor,
}: {
  label: string;
  hint?: string;
  error?: string | null;
  children: ReactNode;
  htmlFor?: string;
}) {
  return (
    <div className="field">
      <label className="field-label" htmlFor={htmlFor}>
        {label}
      </label>
      {children}
      {error ? (
        <span className="field-error" role="alert">
          {error}
        </span>
      ) : hint ? (
        <span className="field-hint">{hint}</span>
      ) : null}
    </div>
  );
}

export function Input({ className = "", invalid = false, ...rest }: InputHTMLAttributes<HTMLInputElement> & { invalid?: boolean }) {
  const classes = ["input", className].filter(Boolean).join(" ");
  return <input className={classes} aria-invalid={invalid || undefined} {...rest} />;
}

export function Select({ className = "", children, ...rest }: SelectHTMLAttributes<HTMLSelectElement>) {
  const classes = ["select", className].filter(Boolean).join(" ");
  return (
    <select className={classes} {...rest}>
      {children}
    </select>
  );
}

export function Textarea({ className = "", ...rest }: TextareaHTMLAttributes<HTMLTextAreaElement>) {
  const classes = ["textarea", className].filter(Boolean).join(" ");
  return <textarea className={classes} {...rest} />;
}

export function Checkbox({ label, className = "", ...rest }: InputHTMLAttributes<HTMLInputElement> & { label?: ReactNode }) {
  return (
    <label className={["checkbox-row", className].filter(Boolean).join(" ")}>
      <input type="checkbox" {...rest} />
      <span>{label}</span>
    </label>
  );
}

export function Panel({
  title,
  sub,
  children,
  className = "",
  actions,
}: {
  title?: string;
  sub?: string;
  children: ReactNode;
  className?: string;
  actions?: ReactNode;
}) {
  return (
    <section className={`panel ${className}`.trim()}>
      {title ? <h3 className="panel-title">{title}</h3> : null}
      {sub ? <p className="panel-sub">{sub}</p> : null}
      {actions ? <div className="row row--between mb-2">{actions}</div> : null}
      {children}
    </section>
  );
}

export function Tag({
  children,
  tone = "default",
  className = "",
}: {
  children: ReactNode;
  tone?: "default" | "gold" | "success" | "danger" | "dim";
  className?: string;
}) {
  const tones: Record<string, string> = {
    default: "",
    gold: "tag--gold",
    success: "tag--success",
    danger: "tag--danger",
    dim: "tag--dim",
  };
  return <span className={`tag ${tones[tone]} ${className}`.trim()}>{children}</span>;
}

export function Alert({
  tone = "info",
  children,
  className = "",
}: {
  tone?: "info" | "error" | "success" | "warn";
  children: ReactNode;
  className?: string;
}) {
  const tones: Record<string, string> = {
    info: "",
    error: "alert--error",
    success: "alert--success",
    warn: "alert--warn",
  };
  return (
    <div className={`alert ${tones[tone]} ${className}`.trim()} role={tone === "error" ? "alert" : tone === "success" ? "status" : undefined}>
      {children}
    </div>
  );
}

export function Spinner({ label = "Loading" }: { label?: string }) {
  return (
    <div className="row" role="status" aria-live="polite">
      <span className="spinner" aria-hidden="true" />
      <span className="dim">{label}</span>
    </div>
  );
}

export function EmptyState({ title, copy, action }: { title: string; copy?: ReactNode; action?: ReactNode }) {
  return (
    <div className="empty">
      <h3 className="empty-title">{title}</h3>
      {copy ? <p className="empty-copy">{copy}</p> : null}
      {action ? <div>{action}</div> : null}
    </div>
  );
}

export function Eyebrow({ children, className = "" }: { children: ReactNode; className?: string }) {
  return <p className={`eyebrow ${className}`.trim()}>{children}</p>;
}

export function PageHeader({
  title,
  lead,
  actions,
  eyebrow,
}: {
  title: ReactNode;
  lead?: ReactNode;
  actions?: ReactNode;
  eyebrow?: string;
}) {
  return (
    <header className="mb-3">
      {eyebrow ? <Eyebrow>{eyebrow}</Eyebrow> : null}
      <div className="row row--between">
        <div>
          <h1 className="mt-0">{title}</h1>
          {lead ? <p className="lead mb-0">{lead}</p> : null}
        </div>
        {actions ? <div>{actions}</div> : null}
      </div>
      <hr className="rule" />
    </header>
  );
}