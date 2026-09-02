-- Phase 5A FK/index integrity correction.
-- All 14 advisor-reported foreign-key gaps receive left-prefix indexes.
-- The one exact redundant non-unique index is removed; the other 23 initially
-- unused indexes are retained because each protects a parent change, governed
-- read path, queue, inbox, uniqueness boundary, or immutable audit path.

drop index public.community_comment_versions_comment_idx;
drop index public.community_comments_parent_idx;

create index community_comment_versions_changed_by_idx on public.community_comment_versions (changed_by_user_id);
comment on index public.community_comment_versions_changed_by_idx is 'Supports auth.users parent changes for version actors.';

create index community_comments_parent_idx on public.community_comments (parent_comment_id, discussion_id)
where parent_comment_id is not null;
comment on index public.community_comments_parent_idx is 'Supports composite parent integrity and reply-tree traversal.';

create index community_discussions_created_by_idx on public.community_discussions (created_by_user_id);
comment on index public.community_discussions_created_by_idx is 'Supports auth.users parent changes for discussion creators.';

create index community_moderation_actions_comment_idx on public.community_moderation_actions (comment_id);
comment on index public.community_moderation_actions_comment_idx is 'Supports comment parent changes for moderation history.';

create index community_moderation_actions_restriction_idx on public.community_moderation_actions (restriction_id);
comment on index public.community_moderation_actions_restriction_idx is 'Supports restriction parent changes for moderation history.';

create index community_moderation_actions_staff_idx on public.community_moderation_actions (staff_user_id);
comment on index public.community_moderation_actions_staff_idx is 'Supports auth.users parent changes for moderation actors.';

create index community_notifications_actor_idx on public.community_notifications (actor_user_id);
comment on index public.community_notifications_actor_idx is 'Supports profile parent changes for notification actors.';

create index community_restriction_lifts_staff_idx on public.community_posting_restriction_lifts (lifted_by_staff_user_id);
comment on index public.community_restriction_lifts_staff_idx is 'Supports auth.users parent changes for lift actors.';

create index community_restrictions_applied_by_idx on public.community_posting_restrictions (applied_by_staff_user_id);
comment on index public.community_restrictions_applied_by_idx is 'Supports auth.users parent changes for restriction actors.';

create index community_restrictions_origin_report_idx on public.community_posting_restrictions (originating_report_id);
comment on index public.community_restrictions_origin_report_idx is 'Supports report parent changes for restrictions.';

create index news_request_decisions_org_idx on public.news_follow_request_resolution_decisions (resolved_organizational_contributor_id);
comment on index public.news_request_decisions_org_idx is 'Supports organization parent changes for Request decisions.';

create index news_request_decisions_person_idx on public.news_follow_request_resolution_decisions (resolved_person_id);
comment on index public.news_request_decisions_person_idx is 'Supports Person parent changes for Request decisions.';

create index news_request_decisions_show_idx on public.news_follow_request_resolution_decisions (resolved_show_id);
comment on index public.news_request_decisions_show_idx is 'Supports Show parent changes for Request decisions.';

create index news_request_targets_resolved_by_idx on public.news_follow_request_targets (resolved_by_user_id);
comment on index public.news_request_targets_resolved_by_idx is 'Supports auth.users parent changes for Request resolvers.';

comment on index public.community_discussions_news_item_idx is 'Supports item-context discussion lookup and uniqueness enforcement.';
comment on index public.community_discussions_team_fk_idx is 'Supports Team parent changes and Team-context discussion reads.';
comment on index public.community_discussions_competition_fk_idx is 'Supports Competition parent changes and Competition-context reads.';
comment on index public.community_discussions_sport_fk_idx is 'Supports Sport parent changes and Sport-context reads.';
comment on index public.community_comments_discussion_created_idx is 'Supports ordered discussion rendering and discussion parent changes.';
comment on index public.community_comments_author_created_idx is 'Supports owner history, separation filtering, and user parent changes.';
comment on index public.community_reports_status_created_idx is 'Supports the pending moderation queue in deterministic order.';
comment on index public.community_reports_comment_idx is 'Supports comment report history and comment parent changes.';
comment on index public.community_reports_reporting_user_idx is 'Supports reporter ownership and user parent changes.';
comment on index public.community_posting_restrictions_user_ends_idx is 'Supports active-suspension checks and user parent changes.';
comment on index public.community_moderation_actions_report_idx is 'Supports append-only moderation history per report.';
comment on index public.community_moderation_actions_target_idx is 'Supports fan moderation history and user parent changes.';
comment on index public.community_moderation_notices_user_unread_idx is 'Supports the fan unread moderation-notice inbox.';
comment on index public.community_notifications_user_unread_idx is 'Supports the fan unread social/request inbox.';
comment on index public.news_follow_request_targets_state_created_idx is 'Supports the pending Request queue in deterministic order.';
comment on index public.news_follow_request_targets_person_fk_idx is 'Supports Person resolution parent changes.';
comment on index public.news_follow_request_targets_organization_fk_idx is 'Supports organization resolution parent changes.';
comment on index public.news_follow_request_targets_show_fk_idx is 'Supports Show resolution parent changes.';
comment on index public.news_follow_request_decisions_staff_idx is 'Supports immutable staff decision audit history.';
comment on index public.user_news_follow_requests_target_idx is 'Supports requester fan-out when a shared target resolves.';
comment on index public.user_news_follow_requests_user_created_idx is 'Supports each fan''s Request history.';
comment on index public.community_posting_restriction_lifts_time_idx is 'Supports chronological lift audit and restoration history.';

