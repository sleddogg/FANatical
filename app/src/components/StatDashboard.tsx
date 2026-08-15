import { Link } from "react-router-dom";
import "./stat-dashboard.css";

export type DashboardStat = Readonly<{
  label: string;
  value: string;
  icon: string;
  detail?: string;
  to?: string;
}>;

export function StatDashboard({
  label,
  primary,
  secondary,
}: {
  readonly label: string;
  readonly primary: readonly DashboardStat[];
  readonly secondary: readonly DashboardStat[];
}) {
  return (
    <section className="stat-dashboard" aria-label={label}>
      <div className="stat-dashboard__primary">
        {primary.map((stat) => <DashboardStatCard key={stat.label} stat={stat} size="large" />)}
      </div>
      <div className="stat-dashboard__secondary">
        {secondary.map((stat) => <DashboardStatCard key={stat.label} stat={stat} size="small" />)}
      </div>
    </section>
  );
}

function DashboardStatCard({ stat, size }: { readonly stat: DashboardStat; readonly size: "large" | "small" }) {
  const content = <>
      <span className="stat-dashboard__label"><i aria-hidden="true">{stat.icon}</i>{stat.label}</span>
      <strong>{stat.value}</strong>
      {stat.detail ? <small>{stat.detail}</small> : null}
    </>;
  return stat.to
    ? <Link className={`stat-dashboard__card stat-dashboard__card--${size} stat-dashboard__card--link`} to={stat.to} aria-label={`View ${stat.label} details`}>{content}</Link>
    : <article className={`stat-dashboard__card stat-dashboard__card--${size}`}>{content}</article>;
}
