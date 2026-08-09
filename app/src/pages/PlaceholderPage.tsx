type PlaceholderPageProps = {
  readonly title: string;
  readonly description: string;
};

export function PlaceholderPage({ title, description }: PlaceholderPageProps) {
  return (
    <section className="placeholder-page" aria-labelledby="page-title">
      <div className="placeholder-page__heading">
        <span className="eyebrow">FANatical</span>
        <h1 id="page-title">{title}</h1>
        <p>{description}</p>
      </div>

      <div className="surface placeholder-surface">
        <span className="placeholder-surface__marker" aria-hidden="true" />
        <p>Feature implementation is intentionally deferred while the shared foundation is established.</p>
      </div>
    </section>
  );
}
