# Build Spec/Tracker

**FANatical Master Build Spec — Tracker / Status Map**

Current status: core feature-system cleanup is complete; Core Platform/App Structure and final backend architecture remain the main pre-implementation review items.

Legend  
 ✓ \= component is mostly complete / keep and clean  
 — \= component exists but needs fleshing / organizing  
 ✕ \= component is missing or barely started

Completeness  
 10/10 \= section is internally consistent enough to move into Codex implementation  
 Anything below 10 \= still needs a consistency/content pass before implementation

## **1\. Core Platform Spec**

Completeness: 9/10

Components

*  	✓ Platform 	purpose 	  
* 	✓ Full-platform 	vision 	  
* 	✓ Core 	philosophy 	  
* 	✓ Main 	app sections 	  
* 	✓ Fan 	identity focus 	  
* 	✓ Keep-users-inside-the-ecosystem 	rule 	  
* 	✓ Reward 	participation philosophy 	  
* 	✓ Experience 	principles	  
* 	— Clean 	final wording 	  
* 	— Remove 	duplicate app behavior / philosophy wording

## **2\. App Shell / Navigation / Team Context**

Completeness: 8/10

Components

*  	✓ Separate 	page structure 	  
* 	✓ Home 	page layout 	  
* 	✓ Inner 	page layout 	  
* 	✓ Fixed 	bottom navigation 	  
* 	✓ Home 	button / logo behavior 	  
* 	✓ Profile 	button behavior 	  
* 	✓ Homepage 	team selector 	  
* 	✓ Inner-page 	navigation bar 	  
* 	✓ Icon 	system rules 	  
* 	✓ Asset 	fallback rules 	  
* 	✓ Global 	selected team context 	  
* 	✓ Add 	/ remove / switch teams 	  
* 	— Primary 	team / secondary team / rival team logic 	  
* 	— Team 	context data model

## **3\. News System**

Authority status: reconciled for the approved News foundation. Later engagement details remain explicitly deferred in the News To-Do List.

Components

* ✓ Chronological personal feed purpose
* ✓ Explicit Author, podcast Show, and organizational-contributor follows
* ✓ Optional factual coverage scopes on News follows
* ✓ Temporary News filters that never mutate global Team context
* ✓ Add to Feed discovery and request behavior
* ✓ Zero-follow EXAMPLE onboarding card
* ✓ Feed, Sitemap, Web Page, Newsletter, and opportunistic API monitoring methods
* ✓ Public written journalism and podcast episodes in v1
* ✓ Publisher-site article destination
* ✓ Canonical News Item-to-FANbase discussion connection
* ✓ In-app notification when a requested News identity becomes available
* ✓ Reversible, evidence-preserving deduplication
* — Signed-out News behavior
* — Exact News rating, reaction, and poll behavior

## **4\. FANbase / Community System**

Completeness: 10/10

Components

*  	✓ FANbase 	purpose 	  
* 	✓ Article 	discussion threads 	  
* 	✓ Locker 	Room concept 	  
* 	✓ Events 	concept 	  
* 	✓ Groups 	concept 	  
* 	✓ FANfotos 	concept 	  
* 	✓ Game 	threads 	  
* 	✓ Team-linked 	community context 	  
* 	✓ Comments 	  
* 	✓ Reactions 	  
* 	✓ Fan 	photo ranking 	  
* 	✓ Badges 	/ Top 10 / Top 50 / Top 100 	  
* 	✓ Posting 	rules 	  
* 	✓ Community 	moderation rules 	  
* 	✓ Reporting 	flow 	  
* 	✓ Thread 	creation rules 	  
* 	— Final 	FANbase implementation schema

## **5\. Cheer / Live Events**

Completeness: 10/10

Components

*  	✓ Cheer 	purpose 	  
* 	✓ Synchronized 	fan interaction concept 	  
* 	✓ One 	moment / one prompt / one action rule 	  
* 	✓ Live 	event connection 	  
* 	✓ Active 	cheer prompt 	  
* 	✓ Real-time 	results 	  
* 	✓ Timed 	prompts 	  
* 	✓ Visual 	sync / karaoke-style cheering	  
* 	✓ Event 	targeting 	  
* 	✓ Geo-targeting 	concept 	  
* 	✓ Participation 	tracking	  
* 	— Reward 	tie-in 	  
* 	✓ Cheer 	creation flow 	  
* 	— Featured 	/ popular cheers 	  
* 	— Admin/operator 	control 	  
* 	✓ High-concurrency 	behavior 	  
* 	— Final 	live-event implementation schema

## **6\. Quiz System**

Completeness: 10/10

Components

*  	✓ Quiz 	Hub	  
* 	✓ Sport 	selection 	  
* 	✓ League 	selection	  
* 	✓ Difficulty 	selection 	  
* 	✓ Quiz 	selection 	  
* 	✓ Random 	Quiz 	  
* 	✓ Browse 	Category 	  
* 	✓ Retake 	Quiz 	  
* 	✓ Create 	Quiz flow 	  
* 	✓ Quiz 	Landing Page 	  
* 	✓ 10-question 	structure 	  
* 	✓ 4-answer 	structure 	  
* 	✓ Timer 	  
* 	✓ Answer 	locking 	  
* 	✓ Correct 	/ incorrect feedback 	  
* 	✓ Auto-advance 	  
* 	✓ Score 	tracking 	  
* 	✓ Results 	screen 	  
* 	✓ Attempt 	tracking 	  
* 	✓ Retake 	cooldown 	  
* 	✓ Central 	quiz data rules 	  
* 	— Sample 	quiz data cleanup 	  
* 	— Difficulty 	scoring logic 	  
* 	— Anti-cheat 	rules 	  
* 	— User-created 	quiz approval 	  
* 	— Final 	quiz implementation schema

## **7\. Profile / Fan Identity**

Completeness: 10/10

Components

*  	✓ Profile 	purpose 	  
* 	✓ Permanent 	fan identity / account ID
* 	✓ Handle
* 	✓ Display 	name
* 	✓ Header 	/ banner 	  
* 	✓ Favorite 	teams / sports 	  
* 	✓ Bio 	section 	  
* 	✓ Fan 	Identity section 	  
* 	✓ Sports 	Played section 	  
* 	✓ Trophy 	Case 	  
* 	✓ Moments 	  
* 	✓ Game 	Face 	  
* 	✓ Fan 	Cave 	  
* 	✓ Memorabilia 	  
* 	✓ Featured 	uploads carousel 	  
* 	✓ Photo 	action view 	  
* 	✓ Owner 	view 	  
* 	✓ Visitor 	view 	  
* 	✓ Rating 	system concept 	  
* 	✓ Ranking 	badge concept 	  
* 	— Public 	vs private profile rules	  
* 	— Profile 	editing rules  
* 	— Rating 	/ ranking math  
* 	— Trophy 	unlock rules  
* 	— Final 	Profile implementation schema

## **8\. Rewards / Ads / Revenue**

Completeness: 10/10

Components

* 	✓ Fan 	Score system  
* 	✓ Fan 	Coins system  
* 	✓ Fan 	Score and Fan Coins separation rule  
* 	✓ Fan 	Score from engagement / performance  
* 	✓ Fan 	Coins from ads / rewards  
* 	✓ Ad 	intensity modes  
* 	✓ Low 	/ Medium / High / Maximum ad choice  
* 	✓ Basic-user 	default ad level  
* 	✓ Full-member 	Ad Intensity control  
* 	✓ Fan 	Coin earning limited to Full Members  
* 	✓ Score 	fairness rule  
* 	— Points 	math  
* 	— Coin 	payout math  
* 	— Streak 	system  
* 	— Tiers 	/ ranks  
* 	— Sponsor 	rewards	  
* 	— Redemption 	system	  
* 	✓ Abuse 	/ fraud prevention framework	  
* 	— Revenue 	logic	  
* 	✕ Partner 	/ advertiser dashboard concept  
* 	— Final 	cost / revenue model

## **9\. Backend / Data / Scale / Safety / Admin**

Completeness: 9/10

Components

* 	✓ Backend 	scale-up concept	  
* 	✓ High-concurrency 	concern identified	  
* 	✓ Instant 	user-action philosophy	  
* 	✓ Batch-heavy-work-later 	philosophy	  
* 	✓ Cache 	popular content concept	  
* 	✓ User 	accounts / membership state	  
* 	✓ Roles 	/ permissions / entitlements	  
* 	— Database 	structure	  
* 	✓ Lightweight 	live-event state	  
* 	✓ Notifications	  
* 	✓ Queues 	/ background jobs 	  
* 	✓ Media 	upload limits 	  
* 	✓ Content 	scanning / moderation checks	  
* 	✓ Reporting 	flow	  
* 	✓ Moderation 	queue	  
* 	✓ Admin 	dashboard requirements	  
* ✓ News Catalog / Resolution administration
* 	✓ Quiz 	approval / review	  
* 	✓ Cheer 	moderation / management	  
* 	✓ Event 	management	  
* 	— Final 	backend architecture / provider choices	  
* 	— Final 	implementation data model	  
* 	— Final 	security / privacy rules

## **10\. Prime Fan / Brand Character**

Completeness: 5/10

Components

*  	✓ Prime 	Fan concept 	  
* 	✓ Brand 	personality direction 	  
* 	✓ Fan-first 	voice 	  
* 	✓ App 	mascot / guide idea 	  
* 	— Role 	inside the app 	  
* 	— Onboarding 	use 	  
* 	— Notification 	voice 	  
* 	— Tutorial 	use 	  
* 	— Brand 	boundaries 	  
* 	— Where 	Prime Fan appears 	  
* 	✕ Final 	Prime Fan behavior rules 	  
* 	✕ Final 	copy style guide

## **11\. Business / Hiring / Growth Plan**

Completeness: 4/10

Components

*  	✓ Hiring 	buildup started 	  
* 	✓ Technical 	lead need identified 	  
* 	✓ Backend 	/ architecture need identified 	  
* 	✓ Product/frontend 	need identified 	  
* 	✓ Content/community 	need identified 	  
* 	— Hiring 	order 	  
* 	— Founder 	role split 	  
* 	— Contractor 	vs employee plan 	  
* 	— Launch 	support plan 	  
* 	— Partnership 	strategy 	  
* 	— Cost 	projections  
* 	— Growth 	plan  
* 	✕ Final 	hiring roadmap 	  
* 	✕ Final 	launch roadmap

# **Overall Completion Snapshot**

Core Platform Spec — 9/10  
 App Shell / Navigation / Team Context — 8/10  
 News System — authority reconciled; later engagement details explicitly deferred
 FANbase / Community System — 10/10  
 Cheer / Live Events — 10/10  
 Quiz System — 10/10  
 Profile / Fan Identity — 10/10  
 Rewards / Ads / Revenue — 10/10  
 Backend / Data / Scale / Safety / Admin — 9/10  
 Prime Fan / Brand Character — 5/10  
 Business / Hiring / Growth Plan — 4/10

# **Working Rule**

Build-critical sections can move into Codex once they are internally consistent and remaining implementation-driven decisions are captured in their To-Do Lists.  
 Next step: Codex reviews the existing code and cleaned spec, then implementation proceeds in focused tasks. Screen- and architecture-driven decisions are resolved as the build develops.

# Core Platform Spec

## **FANATICAL CORE PHILOSOPHY (FINAL)**

---

### **Core Identity**

FANatical is a sports engagement platform that brings together personalized sports news, FANbase communities, quizzes, synchronized Cheer experiences, and a Profile page where fans can build a recognizable fan identity. Rather than treating fans as passive consumers, FANatical is built around active participation in fandom — following, discussing, competing, creating, and cheering on their favorite sports teams.

---

### **Core Rule**

Keep users inside the FANatical ecosystem whenever FANatical can provide the experience directly. External links and services should be used when the content, source, or functionality needs to remain outside the platform.

---

### **Engagement Model**

FANatical is designed to be a sports news aggregator built by the fans themselves. Fans curate their personal News feed by explicitly following human Authors, podcast Shows, and legitimate organizational contributors. Global Team context helps fans discover those News identities but does not silently subscribe them to News. Instead of sending fans into disconnected comment sections across the internet, News discussions live inside FANbase, creating one connected place for fans to talk about the stories they follow.

Engagement extends beyond news into comments, conversations, FANfotos, quizzes, cheers, events, rivalry, and other shared fan experiences. Participation across these systems contributes to a fan’s Profile, giving them a place on the internet to build and display a recognizable fan identity.

---

### **Reward Philosophy: share value from engagement**

FANatical is designed to return some of the value created by fan engagement back to the fans. Participation, knowledge, contribution, and community activity build Fan Score, reputation, rankings, and status, while eligible Full Members can earn Fan Coins through monetized and reward-supported activity.

Fan Score and Fan Coins remain separate so advertising, spending, or reward choices never determine a fan’s competitive standing. The goal is to make participation feel rewarding without turning FANatical into a pay-to-win system.

---

**Monetization Philosophy — generate revenue from engagement without allowing advertising to overwhelm the fan experience.**

Advertising is expected to be FANatical’s primary revenue engine, with the greatest concentration in naturally high-engagement areas such as quizzes and FANbase discussions. Lighter advertising can appear throughout other appropriate areas of the platform, including FANfoto and image-browsing experiences, with exact placement and frequency determined as the app is built and tested.

Basic users receive FANatical’s default ad experience. Full Members can choose their own Ad Intensity — Low, Medium, High, or Maximum — allowing fans to decide how much advertising they are comfortable seeing. Eligible Full Members can earn Fan Coins through monetized and reward-supported activity, allowing FANatical to share part of the value generated by engagement back with the fans.

---

### **Ad Strategy**

Advertising will focus primarily around high-engagement areas such as FANbase discussions and quizzes. FANbase discussions also give FANatical a concrete way to show journalists and publishers the engagement FANatical actually owns, such as reactions, ratings, discussions, and FANatical-generated outbound opens. FANatical must not present those opens as the publisher's total article views or readers.

---

### **Content Strategy — grow from independent creators to major outlets**

Start with independent bloggers, creators, and smaller sports outlets, then use FANatical’s growing audience and FANbase engagement to attract larger publishers. The goal is to become the aggregation and interaction layer between sports content and the fans who follow it.

Normal written journalism remains on the publisher's site. Long term, FANatical may host participating publishers' content directly only where the publisher has explicitly provided the necessary content and permission; FANatical discussion and other FANatical-owned engagement remain inside FANatical.

---

**Team / League Integration (Long-Term)**

* Work toward licensing team and league logos, names, branding, and other official assets.  
* Build partnerships with teams, leagues, and venues that could eventually connect Cheer to live stadium systems such as scoreboards, jumbotrons, and in-arena prompts.  
* Expand access to official team, league, schedule, and event data as partnerships grow.

---

**Experience Principles**

* Fun over friction.  
* Rewarding over punishing.  
* Intuitive over complicated.  
* Distinctive over generic.  
* Connected over fragmented.  
* Fan-first over corporate.

---

**Streak System**

* Users complete any 3 daily tasks to maintain their streak.  
* Daily task pool can include:  
  * read a News item  
  * complete a Quiz  
  * comment or react in FANbase  
  * rate or post a FANfoto  
  * interact with a Cheer  
  * participate in an event, rivalry, or other featured activity  
* Streak progress increases through 10% → 20% → 30% → 40% → 50% and caps there.  
* Missing a day drops the user one level instead of resetting the streak.  
* Streaks provide a small Fan Score benefit for consistent participation.  
* For Full Members, the main streak benefit is increased Fan Coin earning, helping reward regular use of the platform.

---

**Anti-Bloat / Single Source Rules**

* Build only what each feature actually needs; avoid duplicate systems and duplicate stored content.  
* Every item should have one source of truth. A Quiz exists once in the Quiz database, a Cheer once in the Cheer database, and a FANfoto once in the photo system.  
* The same item can appear in multiple places — such as FANfotos appearing in both FANbase and Profile — but both views point to the same underlying record.  
* Downloads or cached copies can exist on a user’s device, but FANatical keeps one canonical version.  
* Reuse shared components and data instead of rebuilding the same function for different pages.  
* Add algorithms or extra complexity only when actual usage shows they are needed.

---

**Core Hook**

* “It’s time to go pro”  
* “Home-field advantage will never be the same again”  
* Stop going  to multiple sources to track down all of the sports news that you consume  
* Finally get rewarded for the time, passion, and participation you already put into being a fan.

# App Structure

# **App Structure**

## **Purpose**

This section defines the shared app frame.

Feature details belong in their own sections.

---

## **Home Page**

Home is the main hub.

Home layout:

* bottom-left: FANatical logo / Home button  
* bottom-center: team selector  
* bottom-right: Profile button  
* main area: hero image/card  
* hero overlay: vertical shortcuts for News, Quiz, FANbase, and Cheer

Team selector:

* horizontal scroll  
* shows selected teams  
* includes Add Team  
* supports overflow arrows if needed

Hero image/card:

* large portrait-style image  
* rounded corners  
* object-fit cover

Sidebar shortcuts:

* vertical icon stack  
* placed over the hero image  
* frosted/translucent style  
* icon-only by default

---

## **All Other Main Pages**

News, FANbase, Cheer, Quiz, and Profile use the inner-page frame.

Inner-page frame:

* bottom-left: FANatical logo / Home button  
* bottom-center: app navigation  
* bottom-right: Profile / account button  
* main area: page-specific content

Inner-page navigation:

* News  
* Quiz  
* FANbase  
* Cheer

The team selector stays on Home.

The homepage hero/sidebar stays on Home.

---

## **Team Context**

The selected team is global.

Changing the selected team affects relevant content across:

* News  
* FANbase  
* Cheer  
* Quiz  
* Profile where relevant  
* Rivalry events  
* Notifications where relevant

Users can add, remove, and switch teams from Home.

Still to define:

* primary team  
* secondary teams  
* rival team  
* default team on first login

## **Team Context Note**

The selected team is the default app context.

News may use the currently selected Team as its initial temporary context and for onboarding, Add to Feed discovery, and relevant News-identity suggestions. Global Team context does not create a News follow or make otherwise-unfollowed journalism eligible for the personal News feed.

News uses its own temporary filters, which may include:

* Selected Team  
* another Team
* Competition
* Sport  
* All Followed News

Changing a temporary News filter must not mutate the selected/global Team context used elsewhere in FANatical. Temporary filters constrain News Items that already qualify through an explicit News follow; they never independently grant feed eligibility.

Detailed News identity, follow-scope, classification, discovery, and feed behavior belongs in the News System section.

---

## **Shared UI / Asset Rules**

Use consistent:

* icons  
* buttons  
* cards  
* spacing  
* loading states  
* error states  
* image placeholders

Icon direction:

* News \= newspaper  
* Quiz \= checklist or brain  
* FANbase \= community/calendar  
* Cheer \= megaphone  
* Profile \= user/avatar  
* Home \= FANatical logo or F

Asset direction:

* team logos stay circular  
* missing images use placeholders  
* images keep their aspect ratio  
* UI should not jump when assets load or fail

---

## **Build Rule**

App Structure defines the frame only.

Each feature section defines what happens inside its own page.

# News page

# **News System**

## **1. Purpose and Personal Feed**

News is FANatical's chronological personal sports-news feed and connects each canonical News Item to FANatical discussion and engagement.

The normal feed is ordered by publication time. No relevance-ranking algorithm controls normal feed order.

A News Item enters the personal feed only through a News identity the fan explicitly follows:

* human Author
* podcast Show
* organizational contributor

Temporary News filters may narrow that eligible set. They never add otherwise-unfollowed journalism.

## **2. Followable News Identities**

### Human Authors

A human Author is a persistent person identity that survives publisher changes. Publisher-specific contributor profiles and bylines remain linked evidence rather than replacement people.

### Podcast Shows

A podcast Show is followable independently of its hosts or other contributors.

### Organizational Contributors

Legitimate organizational identities are followable without being fabricated as humans. Examples include:

* TSN Staff
* Sportsnet Staff
* Canadian Press
* Associated Press
* Reuters
* official Team or newsroom organizations

Following an organizational contributor qualifies only work actually attributed to that identity. Following **TSN Staff** is not the same as following every item TSN publishes.

Written-news publishers such as TSN, ESPN, and Sportsnet are not broad publisher-follow targets merely because they publish News. The previously considered exception for publications with one to three writers is removed.

## **3. Scoped News Follows**

A follow for a human Author, podcast Show where applicable, or organizational contributor may be narrowed by factual observed coverage.

Available scope kinds may include:

* All coverage
* Sport
* Competition
* Competition Edition where useful
* Team

For example, **TSN Staff — NHL only** qualifies TSN Staff items only when the item's current approved factual classification matches NHL.

The scope belongs to the fan's follow preference. FANatical must not invent identities such as **TSN NHL** or **Sportsnet Baseball** unless a genuinely distinct published identity exists.

Several selected scopes match with OR behavior. No selected scope means All coverage.

For the Phase 4 personal-feed contract, selectable follow scopes are **All
coverage**, **Sport**, and **Team**. Competition and Competition Edition remain
valid factual classifications and temporary filters, but are not durable
follow-scope controls in this phase.

### Mute

A fan may temporarily mute an identity they already follow for either:

* 7 days from database `statement_timestamp()`
* 30 days from database `statement_timestamp()`

Mute belongs to the followed identity, never to its publisher. It preserves the
follow and every selected scope, expires automatically without a background job,
and may be ended immediately with **Unmute now**. If another followed and
unmuted identity also qualifies the same News Item, that Item remains eligible.
Unfollowing removes the follow even while it is muted.

## **4. Classification and Feed Eligibility**

News Item classification describes factual sporting scope, including:

* Sport
* Competition
* Competition Edition where useful
* Team or Teams

Classification determines:

* where content factually belongs
* whether it matches an optional follow scope
* whether it matches a temporary News filter
* observed coverage shown during discovery

Classification by itself never creates personal-feed eligibility.

The required order is:

**explicit News follow**
→ **matching selected follow scope, if any**
→ **temporary News filter, if any**
→ **chronological display**

## **5. Global Team Context and Temporary News Filters**

Global FANatical Team follows and selected Team context remain application-wide preferences.

News uses separate temporary navigation and filter state. Entering News through a Team may establish the initial temporary News context, but changing that News filter must not mutate the rest of FANatical's selected/global Team state.

For example, a Manchester United fan may enter through Manchester United and temporarily filter eligible News to Champions League without changing the rest of the app's Manchester United context.

Global Team context supports:

* News onboarding
* Add to Feed discovery
* relevant News-identity suggestions
* initial temporary News context
* selection of the zero-follow EXAMPLE card

Global Team context does not create a News follow or make official Team, organizational, wire, or other journalism automatically eligible.

Temporary filters may include Sport, Competition, Team, and All Followed News.

## **6. Signed-out Demo Mode and Zero-Follow EXAMPLE Onboarding**

### Signed-out Demo Mode

Signed-out visitors may use a deliberately bounded News **Demo Mode**, labelled:

**Demo mode — sign in to save your feed.**

Demo Mode uses real published Items but is not a public all-sports feed and does
not use a shared authenticated dummy account. A versioned, staff-governed
News-domain configuration defines the explicit contributor identities available
in the demo universe. Anonymous callers cannot add arbitrary identities to that
universe.

On first signed-out Demo entry, every identity in the current governed Demo
universe begins selected in isolated browser-local state. Visitors may change
those selections and temporary filters locally, but the selected set is always
limited to and cannot exceed the current governed Demo universe. Demo selections
create no real follows and are never persisted. Sign-in or registration discards
all Demo selections and other Demo state rather than converting them into
account follows, and writes none of it to the real account. Durable follows,
scopes, mute, Dismiss, and every other account-owned action require sign-in.
Anonymous reads expose only the fan-safe fields required to render the configured
demo.

Anonymous contributor profiles and contributor-item lists are an intentional
governed public boundary. They expose only the current stable public contributor
identity and fan-safe published Item fields needed for presentation: public
display name, historical raw attribution, published headline/summary/time,
representative publisher destination, approved preview and factual
classifications. They expose no Auth or staff identity, private profile data,
review case, unresolved question, evidence, decision history or staff operation.

### Signed-in zero-follow EXAMPLE

When a signed-in fan has zero actual News follows, News shows one onboarding example rather than a blank personal feed or a silent subscription.

Use the current/global Team context to:

* select the latest usable story from that Team's canonical official newsroom organization when available
* render it with the normal News-card presentation
* clearly stamp the card **EXAMPLE**
* make **+ Add to Feed** visually prominent
* create no News follow and no personal-feed eligibility

If no usable current official-Team story exists, use a controlled static example. Do not silently substitute unrelated third-party journalism.

The EXAMPLE card is outside the real feed result. Its presence depends on the fan having zero News follows, not merely on a filtered feed returning no items.

The Add to Feed action opens the relevant discovery context, such as:

**Hockey**
→ **NHL**
→ **Edmonton Oilers**

Once the fan creates their first real News follow, the EXAMPLE state disappears and the chronological personal feed becomes the normal page state.

Phase 4 implements the EXAMPLE card's Add to Feed onboarding action. Dismiss is
intentionally unavailable on EXAMPLE, and later Poll, Rating, Reaction or other
engagement behavior remains governed by the normal card rules when each feature
is implemented.

## **7. Add to Feed, Discovery, and Requests**

Fans can discover followable News identities from either direction.

### Hierarchical Discovery

Sport, Competition, and Team navigation can expose available:

* Writers
* Podcasts
* Organizational, Staff, and Wire sources
* official Team or newsroom sources

The identities shown for a scope come from real canonical relationships and observed, approved item classifications.

### Direct Search

Direct search supports:

* human Author
* podcast Show
* organizational contributor

After resolving an identity such as **TSN Staff**, Add to Feed presents its real observed coverage as optional follow scopes. A broad organizational contributor must not be permanently assigned to one Sport or Competition merely because it publishes some work there.

Phase 4 search results use relevance with alphabetical tie-breaking. Unsearched
browsing is alphabetical. **Highest Rated** and **Most Followed** are future
user-selectable discovery sorts only: Phase 4 neither computes nor exposes
cross-fan follower totals or ratings. Those future presentation sorts remain
independent from publisher factual-verification trust, News availability, and
feed eligibility.

### Requests

Missing-identity requests, request persistence, fulfilment, and notifications are
later News work and are not part of Phase 4. The eventual product behavior remains:

If an identity is not found:

**Not found**
→ **Submit Request**

The request retains the requesting fan and the request-to-candidate relationship.

When Resolution later makes the requested identity available:

* update the request status in Add to Feed and Requests
* create an idempotent in-app notification for that fan

Email, browser, and push notification delivery are not part of the current News requirement.

Manage Feed allows fans to inspect and change their explicit follows and coverage scopes.

## **8. News Page and Card Presentation**

The News page retains the responsive FANatical inner-page frame.

Primary areas are:

* temporary News Filter
* centered News title and current filter context
* Add to Feed and Manage Feed
* chronological News Feed
* News Item Cards
* zero-follow EXAMPLE onboarding state

A normal News Item Card includes available:

* publisher or contributor logo/avatar
* headline or episode title
* human or organizational attribution
* podcast Show where applicable
* publication time
* content-type label
* publisher-provided preview image or fallback
* factual scope context where useful
* FANatical-owned action row

The action row may expose:

* Discussion
* Share
* Dismiss for a signed-in fan, with immediate Undo
* Polls when implemented
* Ratings when implemented
* Reactions when implemented
* Add to Feed or identity-profile access where appropriate

Do not display a publisher-style article view count.

Dismiss hides one canonical News Item only for that fan. It changes no follow,
classification, canonical content, publication history, search access, or
discussion. Undo restores the Item at its original chronological position rather
than promoting it to the top. Dismiss is unavailable on the zero-follow EXAMPLE
card and is separate from mute and unfollow.

## **9. Original Content Destination**

For normal third-party written journalism, FANatical does not republish the article body.

The article remains on the publisher's public site. Selecting the article headline, image, or read target opens the chosen public publisher manifestation directly.

The representative destination must be a public `canonical` or `alternate` URL
belonging to the Item's current manifestation assignment; a `wrapper` or
`redirect` remains evidence/history and is never fan-facing. The local Phase 4
migration enforces this rule for every new or changed row with the deliberately
`NOT VALID` `news_manifestation_public_destination_kind_check`. Existing hosted
rows were not scanned, repaired or validated in Phase 4. The service-only
`private.news_manifestation_public_destination_kind_violations` diagnostic is
the required inventory before any later evidence-based repair and constraint
validation under BL-030.

FANatical-owned destinations include:

* canonical Discussion
* Polls
* Ratings
* Reactions
* Author, Show, or organizational profiles
* Add to Feed

No separate FANatical article-detail screen is required for ordinary third-party journalism. The canonical FANatical discussion retains enough News Item context to remain understandable.

## **10. Resolution**

The conceptual responsibilities remain distinct:

**Source Discovery**
= Who or what is this identity or work?

**Monitoring Setup**
= How can FANatical reliably detect future work from it?

Operationally, one Resolution investigation may produce both identity and Monitoring Endpoint evidence when the same fetch or investigation supports both. FANatical must not require redundant processing merely to preserve conceptual terminology.

Resolution can produce durable:

* identity evidence
* publisher identity and URL ownership
* publisher-specific contributor profiles
* organizational-contributor identities
* affiliations and relationships
* observed coverage
* candidate Monitoring Endpoints
* tested Monitoring Setups
* review work

## **11. Byline Resolution**

Byline Resolution is a first-class News responsibility and supports:

* named human Authors
* publisher-specific contributor or byline profiles
* coauthors
* organizational contributors
* Staff or Newsroom attribution
* missing or ambiguous bylines
* persistent human identity across publisher changes

Do not assume every publisher relationship is employment. It may be employee, freelance, contract, guest, columnist, contributor, or another relationship.

Historical attribution remains attached to the correct item even after later identity or affiliation changes.

Ambiguous identity resolution must be reviewable rather than guessed. Merge and split decisions must preserve history and be reversible.

An attribution review structurally identifies the disputed person,
organizational contributor, or Show and the affected byline; freeform context is
not sufficient. While that identity relationship remains under open review, the
Item stays published and its historical raw attribution remains visible, but the
disputed identity alone loses its profile link, follow control, and ability to
qualify the Item. Another undisputed credited identity may still qualify it. A
governed confirmation restores linking and eligibility, and no review details are
fan-visible.

Visible public attribution outranks contradictory hidden metadata. Hidden metadata remains supporting evidence and cannot override what the publisher visibly attributes or independently authorize a destructive identity merge.

## **12. Competition and Classification Model**

News is not permanently constrained to a literal **Sport → League → Team** hierarchy.

The canonical system supports Competition structures appropriate to each sport. Competition kinds may include:

* league
* cup
* championship
* tournament
* tour
* series
* another controlled kind

Examples include:

* NHL
* World Juniors
* World Championship
* Olympic Hockey
* Premier League
* Champions League
* PGA Tour
* individual golf tournaments
* ATP and WTA structures
* individual tennis tournaments

Existing League identities remain valid and map additively into the generalized Competition model.

**team_primary_league** represents a Team's primary app/team-context League. It is not a complete list of every Competition in which that Team participates. Competition Edition participation is the factual membership authority, and News or other Competition-aware features use participation when answering which Competitions a Team participates in.

Classification must represent the factual scope of each News Item rather than infer every current Team Competition from a Team mention.

Player-level News classification is not required in v1, but the canonical model must not prevent it later.

## **13. Filter Groups**

Fan-facing groupings are presentation and navigation structures, not canonical factual Competitions.

Examples include:

* Junior Hockey
* European Club Soccer
* National Teams
* Second Tier

A group references real canonical Competition identities. For example, **Junior Hockey** may present WHL, OHL, and QMJHL. Selecting WHL and OHL retains WHL and OHL as the factual selections; the item is not classified into a synthetic Junior Hockey Competition.

Useful filter groups should evolve from bootstrap data rather than being exhaustively invented before implementation.

## **14. Monitoring Methods and Endpoints**

Normal Monitoring Methods include:

* Feed using RSS or Atom
* Sitemap or News Sitemap
* Web Page or Index
* Newsletter or Email
* Publisher API where genuinely available

Author-specific feeds are especially useful when reliably exposed. Broader publisher or section endpoints may remain active as overlapping sensors.

Several approved Monitoring Endpoints may monitor the same contributor, Show, or expected scope. There is no universal runtime ranking among endpoint types and no opaque endpoint-quality score.

The first endpoint to detect a new work may trigger processing. Later observations become:

* redundancy evidence
* Gap Detection evidence
* explicit endpoint-health evidence

Implementation priority does not create runtime precedence:

* Feed is implemented first
* Sitemap follows early
* Newsletter is required for v1
* Web Page monitoring is added where needed
* Publisher API is opportunistic and is not a v1 prerequisite

Monitoring schedules are configurable. No stale fixed or approximate News refresh interval is authoritative.

## **15. Newsletter and Email**

Newsletter or Email is a v1 Monitoring Method, particularly for independent writers.

If a newsletter points to a public publisher-hosted work, resolve the stable public destination and pass it through the normal content pipeline.

If content exists only inside an email:

* do not republish it without permission
* do not expose subscriber tokens or personalized links
* retain only what is operationally required

Tracking wrappers must resolve to stable canonical public destinations where possible.

Email ingestion is distinct from fan notification delivery.

## **16. Public Podcasts in v1**

Public podcast episodes ship in v1.

A podcast Show is a followable identity independently of its hosts. Podcast RSS is a Feed Monitoring Endpoint.

The News domain supports:

* Show identity
* Episode identity
* contributors and hosts
* RSS GUID and enclosure where appropriate
* public episode destination
* publication timestamp
* factual classifications
* canonical FANatical discussion
* later Polls, Ratings, and Reactions

If the same Episode is embedded or referenced from a written page, it remains one Episode.

Private or paid feeds, full transcript requirements, generalized social ingestion, and generalized video ingestion are outside v1.

## **17. Gap Detection**

Primary Gap Detection comes from FANatical's own overlapping Monitoring Endpoints.

Only compare endpoints whose expected coverage meaningfully overlaps. An entire publisher Sitemap must not be compared with a narrowly scoped Author feed as though every unrelated URL were a miss.

Gap evidence distinguishes stages such as:

* endpoint did not expose the URL
* URL was observed but fetch failed
* extraction failed
* Byline Resolution failed
* Classification failed
* dedupe suppressed the item
* policy intentionally excluded the item
* another processing stage failed

Intentional terminal policy states must not repeatedly reappear as false gaps.

Fan-submitted missed items are another signal.

External aggregators may expose a missed work but are never FANatical feed sources. FANatical resolves and ingests the original contributor, publisher, and public manifestation and investigates the internal miss.

## **18. Deduplication and Wire Content**

Deduplication is reversible and evidence-preserving.

Distinguish:

1. alternate URLs for the same manifestation
2. syndicated or rehosted manifestations of the same underlying work
3. independent journalism covering the same event

Do not collapse independent journalism merely because its event, topic, headline, or opening text is similar.

Retain all manifestations and supporting evidence internally. Suppression of duplicate display must not destructively delete records.

If a decision is reversed, restore the independent News Item going forward while leaving historical discussion, Polls, Ratings, and other community activity on the item where fans originally interacted.

For wire services such as Canadian Press, Associated Press, and Reuters:

* represent the organizational contributor truthfully
* identify matching syndicated manifestations
* retain every manifestation internally
* display one stable accessible public manifestation
* keep the representative destination sticky unless it becomes unavailable

FANatical need not determine which republisher legally owns or first published the wire work merely to select a deterministic fan-facing destination.

## **19. Preview Images**

Use publisher-provided preview metadata such as **og:image** where appropriate.

Do not scrape arbitrary body images. Remote-reference preview images rather than automatically copying or caching them.

Retain publisher-level preview disable and takedown capability and preserve publisher/article context.

If no usable image exists or image loading fails, use the relevant FANatical Sport visual or icon in the same card image area.

## **20. Outbound Opens**

FANatical cannot know a publisher's total article readership and must not display publisher-style article view or reader counts.

FANatical may record outbound article opens that FANatical itself generates. Call them **opens**, not publisher views or readers.

## **21. Canonical Discussion, Polls, Ratings, and Reactions**

Each canonical News Item has one canonical FANatical discussion. The database relationship must prevent duplicate canonical discussions.

A discussion may contain multiple Polls.

Article Ratings are retained as individual events so later Author ratings, awards, rankings, and abuse controls can be derived without losing history.

The following require product approval before their implementation phase:

* rating scale
* rating revision and withdrawal behavior
* News reaction set
* Poll creation, voting, and moderation rules

These deferred engagement details do not block Competition, identity, News Item, feed, monitoring, UI conversion, Resolution, or runtime foundations.

## **22. Publisher Identity and Factual Trust**

News may reuse the existing canonical publisher identity registry, including aliases, URL scopes, ownership relationships, redirects, and provenance.

News availability and monitoring policy remain completely independent from factual-verification trust tiers and applicability.

A publisher may be valid for News without any factual trust assignment. Factual-verification approval does not automatically make a publisher available to News.

The registry's historical **trusted_sources** name must not be presented to fans as an editorial judgment. News policy must not describe a publisher's journalism or opinions as trusted merely because the canonical identity is shared.

## **23. Runtime Architecture**

The settled runtime boundary is:

**Cloudflare executes News background work. Supabase/Postgres owns canonical state and the durable work ledger.**

Cloudflare will eventually provide:

* Workers
* Cron Triggers
* Queues
* Email Worker capability
* exceptional browser rendering later where genuinely necessary

Supabase/Postgres owns:

* canonical News identities and content
* durable work items and leases
* idempotency and evidence
* Monitoring Endpoint observations and state
* Resolution and review state
* Byline Resolution and Classification decisions
* deduplication decisions
* recovery state
* in-app notifications

Cloudflare Queue messages reference durable Supabase work IDs. Queue delivery must not become a second source of job truth, and duplicate delivery must be harmless.

Reuse the existing FANatical work-ledger, lease, wake, recovery, and duplicate-safety patterns where appropriate without reopening or completing the parked agent/backend product work.

News runtime code remains separate from the current asset-only web Worker.

## **24. Bootstrap Direction**

Before beta, bootstrap a useful, intentionally varied set of real:

* publishers
* human Authors
* organizational contributors
* podcast Shows
* Feed endpoints
* Sitemap endpoints
* Newsletter endpoints
* other useful Monitoring Endpoints

Use incoming content to exercise:

* publisher-specific contributor identities
* official Team or newsroom identities
* organizational and wire attribution
* human affiliations and publisher changes
* actual Competition and Team classifications
* observed Author, Show, and organizational coverage
* scoped follows
* Monitoring Setups
* alternate URL, syndication, and wire deduplication
* filter-group requirements
* missing metadata and card fallbacks

Phase 4 uses a row-based fan-safe navigation read model: one current row per
Sport, Competition, or Team. The frontend groups those rows for presentation;
it does not persist a parallel filter hierarchy or synthetic follow targets.

Include deliberately difficult cases such as cross-competition writers, independent newsletter writers, multi-sport Staff identities, official Team content, wire-heavy publishers, shared-owner publications, podcasts, junior hockey, soccer cups, golf, and tennis.

## **25. News To-Do List**

The following are intentionally deferred and are not blockers to the approved foundation phases:

* exact article rating scale
* rating revision and withdrawal behavior
* exact News reaction set
* detailed Poll creation, voting, and moderation rules
* configured monitoring schedules, concurrency, response limits, timeouts, and retry values established from implementation and bootstrap evidence
* final visual treatment for Add to Feed, profiles, and the EXAMPLE onboarding card
* Competition proposal, evidence, verification-policy, decision, and audit workflows before any automated or agent promotion of Competition facts beyond `imported_unverified`
* namespace-aware Competition identifier resolution review before provider-specific ingestion depends on external IDs
* public-versus-private exposure policy for commercial or licensed provider identifiers during the first real provider-ingestion phase
* a shared Competition-participation read model and provider-appropriate Edition resolver before News consumers need those queries
* a real-source/provider mapping spike for incoming Competition, Edition, and participant metadata in the earliest real-content phase
* repository-quality follow-up for existing Profile/Cheer regression tests that are timing-sensitive under the default five-second timeout; the reliable full-suite invocation currently uses one worker and a longer timeout

No deferred item silently restores publisher follows, automatic Team eligibility, classification-created eligibility, local third-party article bodies, fixed refresh intervals, or publisher-style view counts.

# Fanbase / Community System

# **FANbase / Community System**

## **1\. Purpose**

FANbase is the main community hub of FANatical.

It is where fans discuss news, create team conversations, join game threads, share fan photos, organize fan events, and interact with smaller groups.

FANbase should feel active, competitive, emotional, funny, and community-driven without becoming spammy or toxic.

The goal is to give fans a place to react, debate, celebrate, chirp, organize, and show off their fandom without needing separate accounts across every sports site, forum, social app, and group chat.

---

**2\. Main Areas / Screens**

FANbase uses the shared inner-page frame. Unless a specific FANbase screen needs a special layout, FANbase screens use the same general structure:

**Top Bar** \- The FANbase top bar contains:

● Team / Filter button \- upper-left  
● FANbase title \- centered  
● FANbase subheader \- centered context text  
● Create button \- upper-right

The Team / Filter button loads FANbase content for a team the user follows. Selecting a different team from this button updates the global selected team context, the same way team selection works from the Home page. This updates FANbase and other team-aware areas of the app.

The Create button opens the available creation options for FANbase, such as Locker Room thread, Fan Photo, Event, or Group.

**Bottom App Footer**

The FANbase bottom footer uses the shared inner-page footer:

● FANatical logo / Home button \- bottom-left  
● App navigation \- bottom-center  
● Profile button \- bottom-right

**Main Area** \- The FANbase main page acts as the entry point to the six main FANbase areas.

The current visual direction is a clean six-card layout:

● Article Comments  
● Locker Room  
● Fan Photos  
● Game Threads  
● Events  
● Groups

**Article Comments**

Discussion threads created from and connected to News Items. Each News Item can have only one connected Article Comments thread inside FANbase.

**Locker Room**

Standalone fan-created discussion threads. Locker Room is used when fans want to start a conversation that is not tied to a specific News Item. Examples: Coaching tactics, playing time, trade ideas, etc.

**Fan Photos**

Fan photo sharing, rating, ranking, and recognition. Fan Photos will start with three main categories: Game Face, Fan Cave, Memorabilia

**Game Threads**

Live or event-based discussion around specific games. Game Threads are only active during scheduled games or defined live events. After the game or event ends, the Game Thread stays open for a short post-game discussion window before locking. Initial working rule: Game Threads lock 24 hours after the game or event ends.

Locked Game Threads remain readable as archived discussion history.

**Events**

Watch parties, meetups, rivalry events, campus/bar events, and Prime Fan appearances. Events help fans organize around real-world and online fan gatherings.

**Groups**

Smaller public, private, or invite-based fan conversations.

Groups are user-specific, so each fan’s Groups area can look different depending on what they join or create.

Example groups may include:

● personal friend groups  
● family game-day chats  
● local hockey teams  
● fantasy league groups  
● workplace fan groups  
● local bar or watch-party groups  
● city-based supporter groups  
● team-specific private groups

---

**3\. UI Components**

FANbase should use simple, scannable components that make it easy for users to move between discussions, photos, events, groups, and live game conversations.

**Top Bar \-** The FANbase top bar contains:

● Team / Filter button \- hamburger icon \- upper-left  
● FANbase title \- centered  
● FANbase subheader \- centered context text  
● Create button \- plus sign \- upper-right

**Bottom App Footer \-** The FANbase bottom footer contains:

● FANatical logo / Home button \- bottom-left  
● App navigation \- horizontal scroll, including all other main app sections \- bottom-center  
● Profile button \- bottom-right

**Main Area \-**The FANbase main page uses a clean six-card layout. The six main area cards are:

● Article Comments  
● Locker Room  
● Fan Photos  
● Game Threads  
● Events  
● Groups

Main Area Card \- Each main area card should show:

● area title  
● icon or image  
● short description  
● activity indicator where useful  
● unread/new indicator where useful

Visual References to Add Later

● FANbase main page  
● Article Comments screen  
● Locker Room screen  
● Fan Photos screen  
● Game Threads screen  
● Events screen  
● Groups screen

---

**4\. User Flow:** Basic FANbase Flow

User opens FANbase. FANbase loads under the currently selected global team. User sees the FANbase top bar, bottom app footer, and six main FANbase area cards.

**Top Bar Flow**: 

User taps the Filter button. Dropdown list shows followed-team options. User selects a followed team. The selected team becomes the currently selected global team and FANbase reloads under the newly selected team. Note: Other team-aware areas of the app also update to match the newly selected global team.

User taps the Create button. Dropdown list shows available creation options. Initial creation options:

● Locker Room thread  
● Fan Photo  
● Event  
● Group

**Bottom Footer Flow**

User taps the FANatical logo / Home button: User returns to Home.

User selects an icon in the bottom app navigation: The app opens the selected app page.

User taps the Profile button: App goes to the user’s Profile page.

**Main Area Flow \-** User sees the six main FANbase areas:

● Article Comments  
● Locker Room  
● Fan Photos  
● Game Threads  
● Events  
● Groups

User selects one of the six FANbase areas. The selected FANbase section opens.

**Article Comments Flow :** If user selects Article Comments, the Article Comments section opens. Article Comments will display discussion threads created from and connected to News Items.

**Locker Room Flow :** If user selects Locker Room, the Locker Room section opens. Locker Room will display standalone fan-created discussion threads.

**Fan Photos Flow :** If user selects Fan Photos, the Fan Photos section opens. Fan Photos will display Game Face, Fan Cave, Memorabilia, and other approved fan photo categories.

**Game Threads Flow :** If user selects Game Threads, the Game Threads section opens. Game Threads will display scheduled, live, recently closed, and archived game discussions where relevant.

**Events Flow :** If user selects Events, the Events section opens. Events will display watch parties, meetups, rivalry events, campus/bar events, Prime Fan appearances, and other approved fan gatherings.

**Groups Flow :** If user selects Groups, the Groups section opens. Groups will display public, private, invite-based, and user-joined fan conversations where relevant.

---

5\. Rules

**Selected Team Rule**

FANbase defaults to the currently selected global team. The Filter button only shows teams the user follows. Selecting a new team from FANbase updates the global selected team. Users only access team-specific FANbase areas for teams they follow.

**Article Comments Rule**

Each News Item can have only one connected Article Comments thread. Article Comments stay connected to the original News Item.

**Locker Room Rule**

Locker Room threads are standalone fan-created discussion threads. Locker Room threads must be connected to the currently selected team.

**Game Threads Rule**

Game Threads are created for scheduled games or defined live events. Game Threads stay active during the scheduled game or live event. Initial working rule: Game Threads lock 24 hours after the game or event ends. Locked Game Threads remain readable as archived discussion history.

**Fan Photos Rule**

Fan Photos appear in FANbase and Profile where visibility allows. FANbase and Profile should display the same underlying Fan Photo record instead of duplicating it.

**Create Rule**

Users must be signed in to create FANbase content. Initial create options are Locker Room thread, Fan Photo, Event, and Group.

**Moderation Rule**

Users must be signed in to comment, react, rate, upload, join, or report. Spam, targeted harassment, hate speech, porn/gore, illegal content, doxxing, threats, and malicious abuse are not allowed.

**Report Rule**

User-generated FANbase content must be reportable. Reports enter a moderation/review process.

---

## **6\. Data / Labels / Filters**

FANbase content should be structured enough to organize, filter, rank, and moderate.

Labels should be useful, not excessive.

Only ask users for labels that improve:

* feed relevance  
* filtering  
* rankings  
* moderation  
* notifications  
* community organization

Required where relevant:

* user  
* team  
* sport  
* league  
* content type  
* created time

Optional where relevant:

* opponent  
* rivalry  
* event  
* article/source  
* category  
* location  
* media type  
* visibility  
* ranking period

FANfoto categories:

* Game Face  
* Fan Cave  
* Memorabilia

Thread categories may include:

* Articles  
* Locker Room  
* Game Thread  
* Rivalry  
* Event  
* General Team Talk

Filters may include:

* selected team  
* league  
* sport  
* category  
* newest  
* most active  
* top ranked  
* event-based

---

## **7\. Backend / Scale Notes**

FANbase has higher backend risk because users create content, upload photos, comment, react, rate, and report.

Immediate actions:

* create comment  
* create reaction  
* create thread  
* upload request  
* report content  
* join event/group

Batch or cached actions:

* rankings  
* badges  
* trending threads  
* top FANfotos  
* leaderboard-style views  
* Fan Score summaries

Queued actions:

* image processing  
* moderation scans  
* notification delivery  
* badge updates  
* abuse review

Scaling rule:  
User actions should feel instant. Expensive calculations should happen in batches.

Ranking rule:  
Reactions and ratings save quickly, but rankings should update hourly/daily rather than recalculating after every action.

Media rule:  
Photos need upload limits, compression, and moderation. Videos should be treated carefully because they are expensive.

---

## **8\. To Do List**

* exact rating system for FANfotos  
* ranking timeframes: daily, weekly, season, all-time  
* whether exact rank is hidden until ranking cycles close  
* visibility rules for public/private groups  
* who can create events  
* how reports escalate  
* how much banter is allowed before moderation steps in

Future subpage build notes:

Open Decisions / Future UI Component Details

These details should be used later when each FANbase subpage is mocked up or built.

Article Comments Card / Screen

Article Comments cards should show discussion activity connected to News Items.

Article Comments cards may show:

● headline/title  
● source name  
● team context  
● comment count  
● reaction summary  
● latest activity time  
● link back to the original News Item where relevant

Locker Room Thread Card / Screen

Locker Room thread cards should show standalone fan-created discussion topics.

Locker Room thread cards may show:

● thread title  
● creator username  
● team/category  
● comment count  
● reaction summary  
● latest activity time  
● status where relevant

Game Thread Card / Screen

Game Thread cards should show scheduled, live, or recently closed game discussions.

Game Thread cards may show:

● teams playing  
● game/event time  
● live/upcoming/closed status  
● comment count  
● active users where useful  
● linked Cheer activity where relevant

Fan Photo Card / Screen

Fan Photo cards should show user-submitted fan photos from Game Face, Fan Cave, Memorabilia, and other approved fan photo categories.

Fan Photo cards may show:

● photo  
● username  
● team/category  
● rating summary  
● reaction summary  
● comment count  
● ranking badge if ranked

Ranking Badge

Ranking badges show recognition earned by Fan Photos or other ranked fan content.

Ranking badge examples:

● Top 10  
● Top 50  
● Top 100  
● Legendary

Event Card / Screen

Event cards should show watch parties, meetups, rivalry events, campus/bar events, Prime Fan appearances, or other approved fan gatherings.

Event cards may show:

● event title  
● event type  
● team context  
● date/time  
● location or online/watch-party label  
● host  
● RSVP/join count  
● visibility

Group Card / Screen

Group cards should show smaller public, private, or invite-based fan conversations.

Group cards may show:

● group name  
● group type  
● team context  
● member count  
● public/private/invite status  
● latest activity where relevant

Comment Components

Comment areas should be simple and readable.

Comment components may include:

● username  
● avatar  
● comment text  
● timestamp  
● reaction row  
● reply option where allowed  
● report button

Reaction Row

The reaction row lets users respond quickly without needing to write a full comment.

Initial reaction options:

● Like  
● Love  
● Fire  
● Mind Blown

Report Button

User-generated content should include a report option where relevant.

The report button should be available on:

● threads  
● comments  
● Fan Photos  
● Events  
● Groups  
● other user-generated content where needed

Create Button / Creation Options

The FANbase Create button opens available creation options.

Create options may include:

● Locker Room thread  
● Fan Photo  
● Event  
● Group

Future Subpage Flow Notes

Basic FANbase Flow

● User opens FANbase  
● FANbase loads under the selected team context  
● User sees the six main FANbase areas  
● User selects Article Comments, Locker Room, Game Threads, Fan Photos, Events, or Groups  
● User opens a thread, post, photo, event, or group  
● User comments, reacts, rates, reports, joins, or shares internally where relevant

Article Comments Flow

● User opens a News Item  
● User taps Discussion  
● FANatical opens the connected FANbase Article Comments thread  
● If no discussion exists yet, the Article Comments thread is created when the first comment is submitted  
● User comments or reacts  
● Thread stays connected to the original News Item  
● Comment count updates on the News Item Card

Locker Room Flow

● User opens Locker Room  
● User browses standalone fan-created threads  
● User filters by selected team, category, newest, or most active where available  
● User opens a thread  
● User comments, reacts, reports, or shares internally  
● User can create a Locker Room thread if posting rules allow

Create Locker Room Thread Flow

● User taps Create  
● User selects Locker Room thread  
● User enters thread title  
● User selects team/category where needed  
● User writes post body  
● User submits thread  
● Thread appears in Locker Room after basic validation and moderation checks

Game Thread Flow

● Game Thread is automatically created for a scheduled game  
● Users can join before, during, or after the game  
● Thread connects to selected team, opponent, rivalry context, Cheer events, and game-related notifications where relevant  
● Game Thread remains open after the game for post-game discussion and locks 24 hours after the game or event ends  
● Closed Game Threads remain readable as archived discussion history

Fan Photo Flow

● User uploads fan photo  
● User chooses category  
● User adds title/details where relevant  
● Photo appears in Fan Photos  
● Photo appears on Profile where visibility allows  
● Other users rate, react, and comment where allowed  
● Photo can earn badges, rankings, trophies, or profile recognition

Fan Photo Rating Flow

● User opens Fan Photos  
● User views a photo card or photo detail view  
● User rates the photo using the rating control  
● User may also react or comment  
● Rating saves quickly  
● Ranking updates later through scheduled ranking cycles

Event Flow

● User opens Events  
● User browses watch parties, meetups, rivalry events, campus/bar events, or Prime Fan appearances  
● User opens event detail  
● User joins, saves, shares internally, or reports the event where relevant  
● User-created public events may require review depending on visibility and reach

Create Event Flow

● User taps Create  
● User selects Event  
● User enters title, type, date/time, location, team context, and visibility  
● Basic personal/private events can be created directly  
● Public, featured, sponsored, or large-reach events require review before promotion

Groups Flow

● User opens Groups  
● User sees joined groups and discoverable public groups  
● User opens a group conversation  
● User posts, reacts, reports, or shares internally where allowed  
● Private and invite-only groups do not appear in public FANbase feeds

Create Group Flow

● User taps Create  
● User selects Group  
● User enters group name, team context, description, and visibility  
● User chooses public, private, or invite-only  
● Group is created after basic validation  
● Groups with public discovery or large reach may require review

Report Flow

● User taps Report on a thread, comment, photo, event, group, or profile-linked item  
● User selects report reason  
● Report is saved  
● Content may remain visible, be limited, or be temporarily hidden depending on severity and report volume  
● Report enters moderation queue  
● Moderation action is recorded  
● Repeat abuse can affect posting ability, visibility, or account status

# Cheer section

# **Cheer / Live Events**

## **1\. Purpose**

Cheer is the live fan participation section of FANatical. It gives fans a place to find, learn, create, and use cheers, chants, songs, crowd prompts, and fan traditions.

Cheer helps fans synchronize their voices and actions during games, watch parties, rivalry moments, stadium events, and shared sports moments.

The goal is to turn individual fan energy into shared, coordinated, real-time crowd participation.

---

**2\. Main Areas / Screens**

Cheer uses the shared inner-page frame. Unless a specific Cheer screen needs a special layout, Cheer screens use the same general structure:

**Top Bar** \- The Cheer top bar contains:

● Check In button \- upper-left  
● Cheer title \- centered  
● Cheer subheader \- centered context text  
● Filter button \- upper-right, left of Create  
● Create button \- plus sign \- upper-right

Before check-in, the upper-left button shows Check In. After check-in, the main page area switches to the Live Event / Stadium View.

Once checked in, the upper-left control can switch between Stadium View and Cheer Library so users can move between live event participation and the regular Cheer Library.

The Filter button narrows the Cheer Library list.

The Create button opens the Cheer creation flow.

**Bottom App Footer**

The Cheer bottom footer uses the shared inner-page footer:

● FANatical logo / Home button \- bottom-left  
● App navigation \- horizontal scroll, including all other main app sections \- bottom-center  
● Profile button \- bottom-right

**Main Area \-** Cheer has two main areas:

**Cheer Library**

Cheer Library is the default Cheer page. It is a vertical, scrollable, list-style library where users can browse available cheers. Cheer Library will include cheer list items/cards, with detailed card contents defined in UI Components.

Cheer Library may include cheer types such as chants, songs, call-and-response cheers, echo chants, clap patterns, rally prompts, celebration prompts, distraction prompts, rivalry prompts, and fan-created cheers.

**Live Event / Stadium View**

Live Event / Stadium View becomes available after the user checks in to a live game, watch party, venue, stadium event, or other approved live event.

Live Event / Stadium View is where users coordinate live cheer activity during an active event.

Users can submit or vote for cheers they want to start.

When a cheer reaches the required threshold, the cheer can become the active synchronized prompt.

Live Event / Stadium View will need deeper layout work once check-in, event context, voting, thresholds, and active prompt behavior are mocked up.

---

**3\. UI Components**

Cheer should use simple, fast, scannable components that help users find, learn, play, create, and use cheers without making the page feel cluttered.

**Top Bar \-** The Cheer top bar contains:

● Check In button \- upper-left

* Before check-in: **Check In**  
* After check-in, while in Cheer Library: **Stadium View**  
* After check-in, while in Stadium View: **Cheer Library**

● Cheer title \- centered  
● Cheer subheader \- centered context text  
● Filter button \- upper-right, left of Create  
● Create button \- plus sign \- upper-right

**Bottom App Footer \-** The Cheer bottom footer contains:

● FANatical logo / Home button \- bottom-left  
● App navigation \- horizontal scroll, including all other main app sections \- bottom-center  
● Profile button \- bottom-right

**Main Area \-** Cheer has two main UI areas:

**Cheer Library \-** Cheer Library uses a vertical, scrollable list of Cheer Item Cards. 

**Cheer Item Card \-** Each Cheer Item Card should show:

● cheer title  
● cheer type  
● team / sport context  
● short instruction

● cheer action row

**Cheer Item Action Row \-** Each Cheer Item Card should include a simple action row visually attached to the card, likely located on the right side of the card.

Initial Cheer Item Action Row:

● Play it : Play button icon  
● Lyrics : Lyrics page icon  
● Bookmark : Bookmark icon

**Live Event / Stadium View**

Live Event / Stadium View components will be expanded after check-in, event context, voting, thresholds, and active prompt behavior are mocked up.

Current working component direction:

● active event context area  
● active or pending cheer prompt area  
● vote / threshold area  
● available cheer list  
● Cheer Library button \- upper-left, replacing Check In after the user is checked in

---

**4\. User Flow: Basic Cheer Flow**

User opens Cheer section. Cheer loads to the Cheer Library by default under the currently selected global team. User sees the Cheer top bar, bottom app footer, and Cheer Library main area.

**Top Bar Flow**

User taps the Check In button. The check-in page opens. User checks in to a live game, watch party, venue, stadium event, or other approved live event. After check-in, the main area switches to Live Event / Stadium View.

User taps the Filter button. Dropdown list shows available Cheer Library filter options. User selects a filter. The Cheer Library updates.

User taps the Create button. The Cheer creation page opens.

**Bottom Footer Flow**

User taps the FANatical logo / Home button: User returns to Home.

User selects an icon in the bottom app navigation: The app opens the selected app page.

User taps the Profile button: App goes to the user’s Profile page.

**Main Area Flow**

Cheer Library Flow: User browses Cheer Item Cards. User can Play, view Lyrics, or Bookmark a cheer from the Cheer Item Action Row.

Live Event / Stadium View Flow: User sees the active event context, active or pending cheer prompt area, vote / threshold area, and available cheer list. User can submit or vote for cheers they want to start. When a cheer reaches the required threshold, the cheer can become the active synchronized prompt.

Stadium View / Cheer Library Toggle Flow: After check-in, user can switch between Live Event / Stadium View and Cheer Library using the upper-left button.

---

**5\. Rules**

**Selected Team Rule**

Cheer loads under the currently selected global team by default. The Cheer Library can be filtered beyond the selected team where approved filters are available.

**Check-In Rule**

Live Event / Stadium View is only available after the user checks in to a live game, watch party, venue, stadium event, or other approved live event.

**Seat / Area Context Rule**

Check-in can include seating, section, side, zone, venue, or watch-party area context.

Seat / area context can change what part of a synchronized cheer is shown to the user.

Example: for an east-side / west-side chant, users on one side may see one part of the cheer while users on the opposite side see the matching response.

Early versions can use manual seat, section, or area selection. Later versions can use venue maps, ticket data, or location-based assignment where supported.

**Live Prompt Rule**

Cheer uses a one moment, one prompt, one action rule. Live prompts should stay simple, clear, and synchronized.

**Active Prompt Rule**

A live cheer prompt must have a clear start and end point. Users should know what action they are being asked to take

**Live Audio Rule**

Live Event / Stadium View uses visual and timing cues rather than synchronized live audio playback. Cheer audio is primarily used in the Cheer Library for learning and practice

**Threshold Rule**

A cheer will become an active synchronized prompt when the required voting or participation threshold is reached.

**Create Cheer Rule**

Users must be signed in to create or submit a cheer. Normal user-created cheers do not require pre-review before being published for normal use. User-created cheers remain subject to reporting and moderation.

**Bookmark Rule**

Bookmarked cheers save to the user’s Cheer Library and appear near the top of the list.

---

**6\. Data / Labels / Filters**

Cheer data, labels, and filters should support the visible Cheer Library, Cheer Item Cards, check-in behavior, and basic Live Event / Stadium View direction.

Detailed live prompt data, threshold behavior, stadium mapping, and active event data will be defined after those screens are mocked up.

**Core Cheer Item Data \- Each Cheer Item should include:**

● cheer ID  
● cheer title  
● cheer type  
● short instruction  
● lyrics or chant instructions where relevant  
● audio file where relevant  
● created by  
● created time

Optional Cheer Item Data \- Cheer Items may also include the following where relevant:

● team  
● sport  
● league  
● opponent  
● rivalry  
● event  
● venue / location  
● seating area  
● bookmarked status

**Cheer Type Labels** \- Cheer type labels should start simple. Initial cheer type labels:

● chant  
● song  
● call-and-response  
● echo chant  
● clap pattern

**Bookmark Data**

Bookmarking a cheer saves that Cheer Item to the user’s Cheer Library. Bookmarked cheers should appear near the top of the user’s Cheer Library list.

**Check-In Data** \- Check-in data should support access to Live Event / Stadium View. Check-in data may include:

● event  
● team  
● opponent where relevant  
● venue / location  
● seating section  
● side / zone  
● watch-party area  
● check-in status

Venue / Location Note

Check-in should not require FANatical to manually maintain a database of every possible venue, pub, bar, or watch-party location.

Major stadiums and arenas can become managed venue records over time.

**Venue Mapping / Seat Resolver — Production Admin Foundation**

The existing Venue Mapping and Seat Resolver are not disposable development tooling. They are the production foundation for managed-venue fan Check-In and Live Cheer routing.

During development, the tool remains available through its temporary `/internal/...` routes and stays outside normal fan-facing navigation.

When FANatical authentication and admin permissions are implemented, preserve and reuse the working Venue Mapper and Seat Resolver as an authenticated admin-only venue-management system. Replacing the temporary `/internal/...` access must not cause the tool, its data model, or its resolver mechanics to be rebuilt or discarded.

Authorized FANatical administrators and venue administrators should be able to create and maintain managed venue records, physical section mappings, Team Seating Profiles, routing rules, row/seat exceptions, and test seat resolution. The permanent physical venue mapping remains shared across team profiles, and the resolver continues to explain which saved rule produced each routing value.

Venue mappings and Seat Resolver data should move from local development persistence into the canonical FANatical backend/database when that foundation is implemented. Fan Check-In and Live Cheer must read from those same canonical venue records rather than creating a separate venue-routing system.

For smaller venues, pubs, and watch parties, users should be able to search/select a location through a map or place lookup provider, or use an event-created location.

Exact provider and implementation will be decided later.

Seat / Area Context Data

Seat / area context should support synchronized cheers where different users may see different parts of the same cheer.

Example: east-side / west-side chants, section-based chants, or home/away fan prompts.

Early versions can use manual seat, section, side, or area selection.

Later versions can use venue maps, ticket data, or location-based assignment where supported.

**Filters** \- Cheer Library filters should narrow the Cheer Library list. Filter options may include:

● selected global team  
● followed teams  
● sport  
● league  
● cheer type  
● bookmarked cheers  
● live event available  
● rivalry cheers

Default Filter Rule

Cheer loads under the currently selected global team by default.

The Filter button can narrow or expand the Cheer Library list using available Cheer labels.

---

**7\. Backend / Scale Notes**

Cheer has higher backend risk than static pages because Live Event / Stadium View may require many users to act at the same time during a live sports moment.

Backend design should keep normal Cheer Library use simple while preparing for heavier live-event behavior later.

**Immediate Actions \- The following actions should feel fast to the user:**

● load Cheer Library  
● filter Cheer Library  
● play cheer audio  
● open cheer lyrics  
● bookmark cheer  
● open check-in page  
● complete check-in  
● open Live Event / Stadium View  
● submit or vote for a cheer  
● switch between Stadium View and Cheer Library

**Live Event / Stadium View Actions \- Live Event / Stadium View may need near-realtime behavior for:**

● active event context  
● vote / threshold count  
● active or pending cheer prompt  
● prompt start / stop timing  
● seat / area-specific cheer parts  
● available cheer list

**Scaling Rule** \- Cheer should not require every user action to recalculate the entire event state. Live event behavior should use lightweight event state wherever possible. Working live-event state may include:

● event  
● cheer  
● vote count  
● threshold  
● active status  
● start time  
● end time  
● seat / area context where relevant

Timing Rule

Cheer prompts should be prepared before they are needed where possible.

During a live moment, the system should only need to send a simple start/update signal instead of rebuilding the full prompt from scratch.

Seat / Area Rule

Seat, section, side, zone, venue, or watch-party area context may affect what each user sees during a synchronized cheer.

This should be handled without duplicating the entire cheer for every section or seat.

Media Rule

Cheer audio files should be stored and loaded efficiently.

Cheer should avoid heavy media behavior unless needed for the cheer experience.

Queued / Later Work

The following backend behavior should be defined after Live Event / Stadium View is mocked up:

● check-in verification  
● venue / location lookup  
● seat / area mapping  
● voting and threshold behavior  
● active prompt timing  
● synchronized prompt updates  
● event-specific available cheer lists  
● ticket / venue map support where relevant  
● post-event history or participation tracking if added later

synchronized cheers can use one Cheer record with multiple part files or cue tracks; users vote on the Cheer as one item, but Live Event / Stadium View can display different parts to different seat / area groups during the active cheer

live stadium prompts should use visual/timing cues instead of live audio playback; cheer audio should be used mainly for Cheer Library learning/practice and should be preloaded or cached where useful

Scaling rule:  
Cheer should not require every user action to recalculate the entire event state. Live prompts should use lightweight state such as prompt ID, event ID, vote totals, active window, and seat / area group where relevant.

High-concurrency rule:  
The backend should be designed for sudden bursts during major plays, rivalry moments, playoff games, stadium events, and viral prompts.

Timing rule:  
Prompts should be preloaded where possible so the server can send a simple “start now” signal during live moments.

---

8\. To Do List

Mock up Live Event / Stadium View.

Define exact crowd threshold meter design.

Define how Cheer connects to notifications.

Define Check-In Flow.

Define Stadium View / Cheer Library toggle behavior after check-in.

Define Threshold Cheer Flow.

Define Timed Cheer Flow.

Define Create Cheer Flow.

Define Active Cheer Prompt Flow.

Define Live Event / Stadium View layout after check-in, event context, voting, thresholds, and active prompt behavior are mocked up.

Define final Cheer Item data after Cheer Item Card mockup is complete.

Define final Cheer filters after Cheer Library mockup is complete.

Define check-in data after Check-In flow is mocked up.

Define seat / area labels after Stadium View layout is mocked up.

Define live prompt, voting, threshold, timing, and active synchronized prompt data after Live Event / Stadium View is mocked up.

Define geofencing / location verification for venue check-in, fake check-in prevention, and nearby event suggestions.

Define synchronized cheer part files / cue tracks so one Cheer can be voted on as one item while displaying different parts to different seat / area groups.

Define visual/timing cue behavior for live stadium prompts.

Define audio behavior for Cheer Library learning/practice.

	 	  
	 	

## **Future Stadium View/ Cheer Build Notes**

Cheer contains two primary areas:

**Cheer Library**  
 Default Cheer screen. Users browse, play, learn, save, filter, and submit cheers, chants, songs, and fan prompts.

**Live Event / Stadium View**  
 Checked-in event screen for synchronized fan participation during a live game, venue event, watch party, or stadium-style moment.

---

### **Cheer Library**

The Cheer Library is the default Cheer experience.

It contains:

* 	team 	chants  
* 	fight 	songs  
* 	call-and-response 	cheers  
* 	clap 	patterns  
* 	rivalry 	cheers  
* 	crowd 	prompts  
* 	fan-created 	cheers  
* 	featured/popular 	cheers

Users can:

* 	 browse 	cheers  
* 	filter 	cheers by sport  
* 	play 	a cheer  
* 	view 	cheer details  
* 	learn 	timing or words  
* 	save/favorite 	cheers  
* 	submit 	a new cheer  
* 	check 	in to a live event if available

Cheer Library card examples:

* 	“D-Fence 	Clap Clap”  
* 	“Let’s 	Go Oilers”  
* 	“East 	Side / West Side Echo Chant”

Each cheer card may show:

* 	cheer 	title  
* 	sport/category  
* 	play 	button  
* 	details 	button  
* 	popularity/usage 	later if relevant

---

### **Live Event / Stadium View**

Live Event / Stadium View is used after a user checks in to a game, venue, watch party, or live event.

It contains:

* 	active 	event/game context  
* 	crowd 	check-in status  
* 	seating/area 	selection  
* 	available 	cheer prompts  
* 	active 	cheer prompt  
* 	vote/trigger 	system  
* 	crowd 	threshold meter  
* 	countdown/timer  
* 	synchronized 	cheer display

The goal of Stadium View is to coordinate many fans into one shared action.

Seating/area context may include:

* 	upper 	level  
* 	lower 	level  
* 	east 	side  
* 	west 	side  
* 	section 	number  
* 	watch 	party area  
* 	venue 	zone

Early version can use manual seating/area selection.

Later versions may use venue maps, ticket/section data, or location-based assignment.

---

### **Active Cheer Prompt**

An active cheer prompt is the live action currently being coordinated.

Examples:

* 	 start 	a chant  
* 	clap 	pattern  
* 	call-and-response  
* 	distraction 	prompt  
* 	rally 	cheer  
* 	celebration 	cheer  
* 	rivalry 	cheer

Prompt may show:

*  	cheer title  
* 	short instruction  
* 	current vote count  
* 	threshold target  
* 	timer/countdown  
* 	active/inactive state

---

### **Vote / Threshold System**

Users can vote to start a cheer.

When enough users vote for the same cheer, the cheer becomes active.

Example:

* 550 	fans vote “Start Let’s Go Oilers” 	  
* 	threshold is reached  
* 	countdown begins  
* 	synchronized cheer starts

Thresholds may depend on:

* 	event 	size  
* 	venue 	size  
* 	number of checked-in users  
* 	seating/area  
* 	cheer 	type  
* 	admin/operator settings

Future Cheer Flow Details to Preserve:

Threshold Cheer Flow will need to define how users vote for a cheer, how the threshold meter updates, when the countdown starts, when the cheer becomes active, and how the prompt ends.

Timed Cheer Flow will need to define how lyrics, claps, or actions highlight in sequence while users follow the cheer.

Create Cheer Flow will need to define how users submit a new cheer, add team/sport/event context, add lyrics or timing notes

Future Cheer Flow Details / To-Do List:

Define Check-In Flow: how users check in to a game, venue, watch party, stadium event, or approved live event.

Define Stadium View / Cheer Library Toggle Flow: how users switch between Live Event / Stadium View and the regular Cheer Library after check-in.

Define Threshold Cheer Flow: how users vote for a cheer, how the threshold meter updates, when the countdown starts, when the cheer becomes active, and how the prompt ends.

Define Timed Cheer Flow: how lyrics, claps, or actions highlight in sequence while users follow the cheer.

Define Create Cheer Flow: how users submit a new cheer, add team/sport/event context, add lyrics or timing notes

Define Active Cheer Prompt Flow: what users see when a cheer is active, how long it stays active, and what happens when it ends.

Define Live Event / Stadium View layout after check-in, event context, voting, thresholds, and active prompt behavior are mocked up.

To-Do List

Define final Cheer Item data after Cheer Item Card mockup is complete.

Define final Cheer filters after Cheer Library mockup is complete.

Define check-in data after Check-In flow is mocked up.

Define seat / area labels after Stadium View layout is mocked up.

Define live prompt, voting, threshold, timing, and active synchronized prompt data after Live Event / Stadium View is mocked up.

# Quiz page

# **Quiz System**

## **1\. Purpose**

Quiz is the sports knowledge and engagement system inside FANatical.

It gives new fans a way to learn teams, leagues, rules, players, history, rivalries, and sports culture.

It gives experienced fans a way to test themselves, challenge others, build Fan Score, complete streak tasks, and prove their knowledge.

Quiz should feel fast, competitive, repeatable, and easy to understand.

---

## **2\. Main Areas / Screens**

Quiz contains these main areas:

**Quiz Hub**  
Main entry screen for the Quiz section.

**Sport Selection**  
User chooses the sport.

**League Selection**  
User chooses the league.

**Difficulty Selection**  
User chooses the difficulty level.

**Quiz Selection**  
User chooses Random Quiz, Browse Category, Retake Quiz, or Create Quiz.

**Quiz Landing**  
Pre-quiz screen showing quiz details before starting.

**Active Quiz**  
Full-screen quiz gameplay.

**Results Screen**  
Final score, completion details, and next actions.

**Create Quiz**  
User-created quiz submission flow.

---

## **3\. UI Components**

Quiz should use clear, fast, mobile-first components.

Core components:

* Quiz Hub header  
* stats panel  
* sport buttons  
* league buttons  
* difficulty buttons  
* quiz path buttons  
* quiz cards  
* back button  
* Quiz Landing card  
* Start Quiz button  
* question card  
* answer buttons  
* timer bar  
* correct / incorrect feedback  
* Results Screen  
* Play Again button  
* Next Quiz button  
* Create Quiz form  
* ad intensity setting/display where relevant  
* error states  
* empty states

Quiz Hub stats may show:

* streak  
* today’s quiz progress  
* Fan Score  
* Fan Coins  
* completed quizzes  
* average score

Difficulty options:

* All-Star  
* Star  
* League Average  
* Grinder  
* Rookie

Quiz path options:

* Random Quiz  
* Browse Category  
* Retake Quiz  
* Create Quiz

Active Quiz screen should show:

* question text  
* 4 answer buttons  
* Submit button  
* timer bar  
* progress indicator where useful

Results Screen should show:

* final score  
* correct answers count  
* Fan Score earned  
* Fan Coins earned where ad flow applies  
* completion status  
* next action buttons

Visual references to add later:

* Quiz Hub  
* sport/league/difficulty selection  
* Quiz Landing  
* Active Quiz question screen  
* Results Screen  
* Create Quiz flow  
* ad/reward flow after quiz

---

## **4\. User Flow**

### **Basic Quiz Flow**

User opens Quiz Hub  
User chooses sport  
User chooses league  
User chooses difficulty  
User chooses quiz path  
User lands on Quiz Landing screen  
User taps Start Quiz  
Active Quiz begins  
User answers 10 questions  
Results screen appears  
User can play again \- same category but different quiz as repeating an already completed quiz is not available until the cooldown period lapses, choose next quiz, or return to Quiz Hub

---

### **Quiz Selection Flow**

Flow order:

1. Quiz Hub  
2. Sport Selection  
3. League Selection  
4. Difficulty Selection  
5. Quiz Selection  
6. Quiz Landing  
7. Active Quiz  
8. Results Screen

Each step replaces the previous step.

Only one step should be active at a time.

Back navigation should preserve previous selections where possible.

---

### **Random Quiz Flow**

User selects Random Quiz  
System filters quizzes by selected sport, league, and difficulty  
System picks one available quiz  
Quiz Landing opens  
User taps Start Quiz

If no quiz exists, show a clear “No quizzes available for this selection” message.

---

### **Browse Category Flow**

User selects Browse Category  
System shows quizzes matching selected sport, league, and difficulty  
User can browse available quiz categories or quiz cards  
User selects a quiz  
Quiz Landing opens  
User taps Start Quiz

If no quizzes exist, show a clear “No quizzes available” message.

---

### **Retake Quiz Flow**

User selects Retake Quiz  
System shows eligible completed quizzes  
Only quizzes past the cooldown period appear  
Quizzes previously scored 100% should appear for retake  
User selects a quiz  
Quiz Landing opens  
User taps Start Quiz

Default cooldown:

* 14 days

If no retakes are available, show “No retakes available yet.”

---

### **Active Quiz Flow**

Active Quiz replaces the regular UI.

During Active Quiz:

* no stats panel  
* no navigation  
* no distractions

Each quiz has:

* 10 questions  
* 4 answer choices per question  
* 1 correct answer per question  
* timer per question

**When user selects an answer:**

 ● selected answer is highlighted  
 ● user may change their selection before submitting  
 ● Submit button becomes active

**When user taps Submit:**  
 ● lock all answer buttons  
 ● show correct / incorrect feedback  
 ● highlight the correct answer \- green  
 ● highlight selected wrong answer if applicable \- red  
 ● wait two seconds  
 ● move to the next question

If the timer expires before a selection is made:

* treat question as incorrect  
* highlight correct answer  
* wait two seconds  
* move to next question

After question 10:

* calculate score  
* save attempt  
* show Results Screen

---

### **Create Quiz Flow**

User opens Create Quiz  
User confirms sport, league, and difficulty  
User chooses topic  
User adds optional tags  
User enters quiz title and short description  
User creates exactly 10 questions  
User adds 4 answer choices per question  
User selects 1 correct answer per question  
User suggests difficulty level  
User reviews quiz  
User submits quiz  
Quiz enters approval/review before public use where needed

Create Quiz should be structured step-by-step.

Do not stack all creation steps on one long screen.

---

## **5\. Rules**

Quiz does not auto-start.

User must tap Start Quiz from Quiz Landing.

Each playable quiz should have exactly 10 questions.

Each question should have exactly 4 answer choices.

Each question should have exactly 1 correct answer.

Do not allow skipping questions during Active Quiz.

Do not allow multiple answer selections on the same question.

Answer selection does not become final until the user taps Submit.

User may change their selected answer before submitting.

After Submit is tapped, the answer is locked and cannot be changed.

Timer starts when the question is displayed.

If timer expires, the question is marked incorrect.

Results are shown only after the full quiz is completed.

Quiz attempt history should not overwrite previous attempts.

Retake cooldown should prevent immediate repeat farming.

User-created quizzes require complete data before submission.

User-created quizzes should go through approval/review before public use where needed.

---

### **Ad Intensity Rule**

Quiz can connect to the user’s Ad Intensity setting.

Ad Intensity options:

* Low \= fewer ads, fewer Fan Coins  
* Medium \= balanced ads and Fan Coins  
* High \= more ads, more Fan Coins  
* Maximum \= High, plus frequent video ads

The user controls their own ad intensity.

Fan Score should not be affected by ad intensity.

Fan Coins can be affected by ad intensity.

Ad intensity should be treated as part of the user-controlled rewards experience, not as part of quiz skill scoring.

---

### **Anti-Cheat / Protection Rules**

Quiz should include reasonable anti-cheat protections.

Protection options may include:

* per-question timer  
* replay limits  
* retake cooldown  
* cycling through other quizzes before repeating the same quiz  
* disabling screenshots or screen capture during active quiz if technically possible

Anti-cheat should protect quiz integrity without making the app annoying to use.

---

## **6\. Data / Labels / Filters**

Quiz needs structured data so quizzes can be searched, filtered, played, scored, and retaken.

Core quiz data:

* quiz ID  
* sport  
* league  
* submitted difficulty  
* calibrated difficulty where relevant  
* topic  
* title  
* short description  
* average score  
* questions  
* created by  
* approval status  
* created time

Each question needs:

* question text  
* 4 answer choices  
* correct answer  
* question order

Optional quiz tags:

* team  
* player  
* event  
* rivalry  
* season  
* playoffs  
* draft  
* awards  
* records  
* transactions  
* moments

Topic examples:

* Rules  
* General Knowledge  
* History  
* Players  
* Playoffs  
* Records  
* Awards  
* Transactions  
* Draft  
* Rivalries  
* Moments

User attempt data:

* user ID  
* quiz ID  
* score  
* answers selected  
* completed time  
* completion status  
* retake eligibility  
* time spent where useful

Filters may include:

* sport  
* league  
* difficulty  
* topic  
* team  
* player  
* event  
* completed/uncompleted  
* retake eligible

Selection state should track:

* selected sport  
* selected league  
* selected difficulty  
* selected quiz ID

---

### **Difficulty Calibration**

Difficulty can start as a user-suggested value when a quiz is submitted.

Example:

* creator submits quiz as Rookie, Grinder, League Average, Star, or All-Star

Over time, actual quiz performance can help calibrate difficulty.

Performance logic:

* high average score \= quiz is easier  
* low average score \= quiz is harder  
* harder quizzes may be worth more Fan Score if that rule is approved later

The system should keep the submitted difficulty and the performance-based difficulty separate

This allows the app to start simple while improving quiz difficulty accuracy over time.

---

## **7\. Backend / Scale Notes**

Quiz is relatively cheap compared to media-heavy features.

Most quiz activity is structured text, button taps, scores, and attempt records.

Immediate actions:

* load quiz options  
* select sport/league/difficulty  
* load quiz landing  
* start quiz  
* submit answer  
* lock answer state  
* calculate result  
* save attempt

Batch or cached actions:

* average scores  
* leaderboards  
* difficulty calibration  
* completed quiz stats  
* Fan Score summaries  
* retake eligibility lists  
* quiz popularity rankings

Queued actions:

* user-created quiz review  
* moderation checks  
* badge updates  
* streak updates  
* notifications  
* reward summaries  
* ad/reward reconciliation where relevant

Scaling rule:  
Answer submission should feel instant.

Heavy ranking, averages, difficulty calibration, and leaderboard calculations can update in batches.

Data rule:  
Quiz questions should live in a centralized quiz data source.

Do not duplicate quiz data across pages.

Attempt rule:  
Completed attempts should be stored as separate records and not overwrite previous attempts.

Rewards rule:  
Fan Score and Fan Coins must stay separate.

Fan Score is tied to quiz performance and engagement.

Fan Coins are tied to ad/reward systems.

---

## **8\. To Do List**

Need to decide:

* exact Quiz Hub layout  
* exact stats shown on Quiz Hub  
* final difficulty names and order  
* exact Fan Score formula  
* whether harder quizzes earn more Fan Score  
* whether quiz completion affects streaks  
* whether Fan Coins appear after quiz through ad flow  
* exact ad placement after or between quizzes  
* exact Low / Medium / High/ Maximum ad intensity behavior  
* exact retake cooldown  
* exact anti-cheat rules  
* whether screenshot blocking is possible or worth using  
* approval process for user-created quizzes  
* who can create quizzes  
* whether users earn recognition for creating popular quizzes  
* whether Create Quiz is available immediately or locked behind user status  
* whether quiz questions can include images later  
* exact sample quiz data needed for implementation and testing

# Profile page

# **Profile / Fan Identity**

## **1\. Purpose**

Profile is the fan identity system inside FANatical.

It gives each user a place to show who they are as a fan, what teams they support, what sports they care about, what they have played, what they collect, what moments matter to them, and how they rank inside the FANatical community.

Profile should feel like a sports card, trophy case, fan scrapbook, and reputation page combined.

The goal is to let users build a recognizable fan identity inside their communities.

---

## **2\. Main Areas / Screens**

Profile contains these main areas:

**Profile Header**  
Top profile area with display name, handle, avatar, optional tagline, and settings/profile controls.

**Fan Photos**  
Main visual profile area for Game Face, Fan Cave, and Memorabilia photos.

**Stats Panel**  
Fan Score, Fan Coins, streak, tier, rank, and other high-level user stats.

**Bio 👤**  
Compact row-style personal/fan-card info.

**Fan Identity 🛡️**  
Favorite teams, players, rituals, superstitions, and fan history.

**Sports Played 🏃**  
Sports the user has played, position, level, years played, and awards.

**Trophy Case 🏆**  
Visual achievement area showing earned and locked trophies.

**Moments 📸**  
Story-style fan memories, photos, events, and meaningful sports moments.

**Photo Action View**  
Detailed view for Game Face, Fan Cave, Memorabilia, or other fan photo content.

**Profile Edit / Settings**  
Owner-only editing and account/profile controls.

---

## **3\. UI Components**

Profile components should be listed and designed roughly in screen order.

Top area:

* profile header  
* avatar  
* banner/header image  
* display name  
* handle
* optional tagline  
* settings button for owner  
* public avatar/profile button for visitor

Main visual area:

* Fan Photos carousel or card stack  
* Game Face card  
* Fan Cave card  
* Memorabilia card  
* photo ranking badge where relevant

Stats area:

* Fan Score  
* Fan Coins  
* Streak  
* Tier  
* Rank

Section switcher: Only one will be shown at a time, the user can select default displayed section in their settings.

* Bio 👤  
* Fan Identity 🛡️  
* Sports Played 🏃  
* Trophy Case 🏆  
* Moments 📸

Content panel:

* Bio \= compact row system  
* Fan Identity \= compact row system  
* Sports Played \= compact row system  
* Trophy Case \= visual grid only  
* Moments \= story cards

Photo Action View:

* image  
* front/back card flip  
* title/details  
* positive interaction row  
* comment shortcut  
* fullscreen view

Ranking badge examples:

* Top 10  
* Top 50  
* Top 100

Visual references to add later:

* Profile Header  
* Fan Photos carousel/card stack  
* Stats Panel  
* Bio/Fan Identity/Sports Played row layout  
* Trophy Case grid  
* Moments story card  
* Photo Action View  
* Ranking badge display

---

## **4\. User Flow**

### **Basic Profile Flow**

User opens Profile  
User sees Profile Header  
User sees Fan Photos and Stats Panel  
User selects Bio 👤, Fan Identity 🛡️, Sports Played 🏃, Trophy Case 🏆, OR Moments 📸  
Content panel updates based on the above selected section  
User opens photos, moments, trophies, or profile details as needed

---

### **Owner Profile Flow**

User opens their own Profile  
User can edit profile details  
User can update avatar/banner/tagline  
User can manage Bio, Fan Identity, Sports Played, Trophy Case, and Moments  
User can manage Game Face, Fan Cave, and Memorabilia photos  
User can view exact rankings and achievement progress  
User can open settings

---

### **Visitor Profile Flow**

User opens another fan’s Profile  
User sees public profile information  
User sees public stats  
User sees public Fan Photos, Moments, and Trophy Case items where allowed  
User can interact positively with allowed fan photos  
User cannot edit anything

Positive interactions may include:

* rating  
* like  
* love  
* fire  
* comment  
* ranking support  
* badge/status recognition

---

### **Fan Photo Flow**

User adds a Game Face, Fan Cave, or Memorabilia photo  
Photo appears on Profile  
Photo appears in FANbase by default unless privacy/visibility settings block it  
Other users can rate, react, and comment where allowed  
Photo can earn ranking badges, trophy recognition, or item status after enough ratings/votes

---

### **Photo Action Flow**

User taps a photo  
Photo opens in action/detail view

Owner actions:

* edit  
* flip/view details  
* fullscreen

Visitor actions:

* rate  
* like  
* love  
* fire  
* comment  
* flip/view details  
* fullscreen

---

## **5\. Rules**

Only show filled profile fields.

Do not display empty rows just because a field exists.

Bio, Fan Identity, and Sports Played should use compact row layouts.

Trophy Case should be visual first.

Moments should use story-style cards.

Owner view and visitor view behave differently.

Owner can edit their own content.

Visitors can view, and interact only where allowed.

Fan photo interaction should stay positive.

Do not use downvote-style mechanics unless intentionally added later.

Profile connects directly to FANbase because user photos, rankings, comments, and recognition appear in both places.

Fan Photos appear in FANbase by default unless privacy or visibility settings block them.

Public Profile should not expose private account settings.

Permanent fan identity rule: The stable internal account/user ID is the fan's permanent identity. It is never derived from or replaced by a handle or display name, never changes, and is never displayed. Trophies, follows, comments, tags, history, and everything else a fan owns remain attached to that permanent identity.

Handle rule: The handle is a mutable public label attached to the permanent fan identity. It is case-insensitively unique among currently claimed handles. `@` is presentation syntax and is not stored. A use of a handle resolves to the permanent fan identity that holds it at the time of the action.

Display name rule: The display name is a separate mutable profile field. It is not unique and is never an identifier.

Rename and reassignment rule: Renaming `@brad` to `@bradley` does not change the fan or any ownership. If a released handle is later claimed by someone else, the new holder receives only that public label and inherits no mentions, trophies, follows, comments, or history. Handle-release mechanics remain deferred.

Operational identity rule: Auth users mapped by `catalog_actors` as agents or services are operational identities, not fans. Their permanent Auth/catalog identity remains intact for permissions, audit history, verification decisions, and provenance even if shared bootstrap requires a technical profile row. Such a row never owns a public fan handle and is excluded from fan-facing profile discovery, tagging autocomplete, leaderboards, and equivalent fan-only surfaces. Each canonical operational `actor_key` is automatically reserved in the fan handle namespace; no second operational naming field is derived for that purpose.

Population rule: Any automation described as applying to “every fan,” “every profile,” or another population must state exactly which records that population includes and use a canonical enforceable query or constraint for it. The existence of an Auth user or technical profile row alone never implies membership in the fan population.

---

## **6\. Data / Labels / Filters**

Core profile data:

* permanent internal account/user ID — never displayed
* handle — mutable public label, case-insensitively unique while claimed, stored without `@`
* display name — mutable and non-unique
* avatar  
* banner/header image  
* optional tagline  
* favorite teams  
* favorite sports  
* profile visibility  
* created time

Bio 👤 fields may include:

* FANatical name  
* given name  
* nickname  
* birthplace  
* height  
* weight  
* jersey number  
* throws  
* shoots  
* bats  
* golf  
* kicks

Fan Identity 🛡️ fields may include:

* primary team  
* primary team since  
* secondary team  
* secondary team since  
* rival team  
* favorite players  
* game day ritual  
* superstitions

Sports Played 🏃 fields may include:

* sport  
* years played  
* position  
* level  
* awards

Trophy Case 🏆 data may include:

* trophy ID  
* trophy name  
* earned status \- trophy in full color  
* locked status \- trophy shaded out  
* earned date  
* achievement type  
* ranking/event connection

Moments 📸 data may include:

* title  
* optional image  
* story  
* optional event/date  
* team/sport/league tags where relevant

Fan Photo categories:

* Game Face  
* Fan Cave  
* Memorabilia

Photo data may include:

* image  
* title  
* origin  
* description  
* category  
* team  
* league  
* sport  
* rating summary  
* reaction summary  
* comment count  
* ranking badge  
* item status  
* owner ID  
* visibility

Positive reaction data may include:

* like  
* love  
* fire  
* comment  
* rating  
* ranking support

Filters may include:

* team  
* league  
* sport  
* photo category  
* ranked  
* newest  
* highest rated  
* trophies earned  
* moments

---

## **7\. Backend / Scale Notes**

Profile has moderate backend and media cost because it includes photos, ratings, rankings, trophies, and profile data.

Immediate actions:

* load profile  
* edit profile  
* save profile field  
* open photo  
* rate photo  
* react to photo  
* comment on photo  
* view trophy/moment

Batch or cached actions:

* profile stats  
* ranking badges  
* top photos  
* trophy unlocks  
* Fan Score summaries  
* public profile previews

Queued actions:

* image processing  
* moderation scans  
* badge updates  
* trophy updates  
* ranking updates  
* notification delivery

Ranking rule:  
Ratings/reactions save quickly, but rankings and badges should update in batches.

Qualification rule:  
Photos/items need enough ratings or votes before qualifying for public rankings.

Example:

* item must receive enough ratings before entering team, league, sport, or category rankings  
* possible threshold examples: 50 votes, 100 votes, or another approved minimum

Public ranking rule:  
Public feeds can show badge tier first, such as Top 10 / Top 50 / Top 100, without showing exact rank immediately.

Reason:

* helps reduce voting bias

Owner profile rule:  
Owner can see exact rank where relevant.

End-of-cycle rule:  
Rankings can lock at the end of a ranking period.

After rankings lock, exact ranks can become visible as achievement history.

Recognition rule:  
High-rated items can earn status labels after enough ratings.

Example:

* 4.8+ rating, with enough votes, may earn Legendary status

Profile/FANbase connection:  
Photos appear on both Profile and FANbase where visibility allows, but the underlying photo record should not be duplicated unnecessarily.

Privacy rule:  
Public profile data and private account/settings data should stay separated.

Media rule:  
Profile images and fan photos need size limits, compression, and placeholders.

---

## **8\. To-Do List**

* exact Profile Header layout  
* exact Fan Photos carousel/card behavior  
* whether users choose displayed Fan Photos or system selects them automatically  
* exact public vs private profile fields  
* whether given name is public, private, or optional  
* exact Stats Panel fields  
* exact trophy types  
* exact trophy unlock rules  
* exact rating system for photos/items  
* exact positive reaction list  
* exact minimum vote/rating count before ranking eligibility  
* exact ranking timeframes  
* whether Moments can include video  
* whether users can comment on Moments  
* whether visitors can rate all Fan Photo categories  
* upload limits and image requirements  
* profile visibility options
* username claim UI for claiming or changing the handle

# Rewards/Ads/Revenue

# **Rewards / Ads / Revenue**

## **1\. Purpose**

Rewards / Ads / Revenue defines how FANatical separates fan reputation, reward currency, ads, and business sustainability.

This section must keep two systems clearly separated:

**Fan Score** \= skill, participation, reputation, rankings, and community status.

**Fan Coins** \= reward currency connected to ads, rewards, and future redemption.

Fan Score should feel earned.

Fan Coins should feel controlled, optional, and reward-based. The goal is to make ads feel like a user-controlled rewards system, not random app punishment.

---

## **2\. Main Areas / Screens**

Rewards, ads, and revenue are cross-app systems rather than one standalone feature page

Rewards, ads, and revenue appear across other parts of the app.

Primary locations:

**Profile**  
Fan Score and Fan Coins are displayed in the user’s stats area.

**Quiz**  
Quiz results show quiz performance, such as 8/10.  
Fan Score impact is calculated separately once the scoring formula is approved.  
Fan Coins appear separately when an ad/reward flow applies.

**Profile Settings / App Settings**  
Ad Intensity control lives here for full members. Basic users use FANatical’s default ad level.

**Photo Ranking / FANbase**  
Photo viewing, rating, and ranking activity can support ad opportunities.

**Future Rewards / Redemption Area**  
Redemption details are not designed yet.

**Internal Business Planning**  
Revenue, ad performance, reward cost, and app cost are tracked internally.  
This is not a user-facing screen.

---

## **3\. UI Components**

Use only the components that have a defined home.

Profile stats area:

* Fan Score  
* Fan Coins  
* streak/status/rank where relevant

Quiz result area:

* quiz score, such as 8/10  
* Fan Score impact if approved  
* Fan Coins earned if ad/reward flow applies

Settings:

* Ad Intensity control  
* Low / Medium / High / Maximum options  
* short explanation of the tradeoff

FANbase / Photo Ranking:

* photo cards  
* rating controls  
* positive reactions  
* ranking badges  
* ad placement between batches where approved

Future rewards area:

* not designed yet

Internal tracking:

* not user-facing

---

## **4\. User Flow**

### **Fan Score Flow**

User completes a skill, participation, or community action  
System records the action  
Fan Score updates according to approved rules  
Fan Score appears in Profile

Fan Score can come from:

* quiz performance  
* streaks  
* Cheer participation  
* FANbase participation  
* photo rankings  
* trophies  
* community recognition  
* promotional participation/reward actions where applicable  
* event/check-in participation

---

### **Fan Coins Flow**

Fan Coins can only be earned by full members. Basic users may see ads but do not accumulate Fan Coins.

User completes a qualifying ad/reward action  
System automatically awards Fan Coins  
Fan Coins appear in Profile / stats area  
User does not manually accept the coins

Fan Coins can come from:

* rewarded ads  
* ad-supported quiz reward flow  
* photo ranking ad flow  
* Ad-supported FANbase engagement

---

### **Ad Intensity Flow**

Basic users receive FANatical’s default ad level, set high enough to reasonably cover the cost of supporting that user. Once the user becomes a full member, the Ad Intensity control becomes available. Full members can choose Low, Medium, High, or Maximum.

User opens Ad Intensity setting  
User chooses Low, Medium, High, or Maximum  
System adjusts ad and reward frequency  
Fan Coin earning opportunities adjust based on that setting

Ad Intensity:

* Low \= fewer ads, fewer Fan Coins \- enough ads to make user ‘free’ for FANatical  
* Medium \= balanced ads and Fan Coins  
* High \= more ads, more Fan Coins  
* Maximum \= high, plus frequent video ads

---

### **Photo Ranking Ad Flow**

User views and rates fan photos  
User moves through a batch of photos  
A small ad or rewarded ad opportunity appears between batches  
User continues rating/ranking content  
Fan Coins are awarded automatically where the ad/reward rules apply

---

## **5\. Rules**

Fan Score and Fan Coins must stay separate.

Fan Score rules:

* Fan Score is tied to skill, participation, rankings, streaks, and community reputation.  
* Fan Score is displayed in Profile.  
* Fan Score is not affected by Ad Intensity.  
* Fan Score is not earned by simply watching more ads.  
* Fan Score is not buyable.

Fan Coins rules: Fan Coins can only be earned by full members.

● Basic users do not earn Fan Coins from ads or other Fan Coin reward flows.

* Fan Coins are tied to ads, rewards, and promotional reward systems.  
* Fan Coins are displayed in Profile.  
* Fan Coins are affected by Ad Intensity.  
* Fan Coins are awarded automatically after qualifying actions.  
* Fan Coins need transaction history.

Ad Intensity rules:

* Basic users use FANatical’s default ad level and cannot select their own Ad Intensity.  
* Full members control their own Ad Intensity.  
* Low / Medium / High / Maximum are available to full members.  
* Low \= fewer ads, fewer Fan Coins  
* Medium \= balanced ads and Fan Coins  
* High \= more ads, more Fan Coins  
* Maximum \= High, plus frequent video ads  
* ad intensity should not make the core app annoying or unusable

Quiz rule:

* Quiz score is shown as quiz performance, such as 8/10.  
* Fan Score calculation is separate and still needs final rules.  
* Fan Coins from quiz-related ads/rewards are separate from quiz score.

Photo/media rule:

* FANatical should not encourage uncontrolled media uploads.  
* Photo uploads should be compressed, limited, and moderated.  
* Photo viewing, rating, ranking, and reacting are the valuable engagement loops.  
* Uploaded videos are avoided until the business can afford them.

No pay-to-win rule:

* users cannot buy Fan Score, quiz rank, photo rank, trophies, or reputation.

---

## **6\. Data / Labels / Filters**

Core data:

* user ID  
* Fan Score  
* Fan Coin balance  
* Ad Intensity setting  
* transaction history  
* reward/ad event history

Fan Score event data:

* activity type  
* score impact  
* reason  
* timestamp  
* related quiz/thread/photo/event

Fan Coin transaction data:

* transaction ID  
* amount earned/spent  
* source  
* timestamp  
* status

Transaction statuses:

* pending  
* completed  
* failed  
* reversed

Ad Intensity values:

* Low  
* Medium  
* High  
* Maximum

Photo/ranking ad data:

* photo batch ID  
* number of photos viewed  
* number of ratings submitted  
* ad shown  
* ad completed where relevant  
* Fan Coins earned where relevant

---

## **7\. Backend / Scale Notes**

Fan Coins need ledger-style tracking.

Do not only store one editable balance.

Every earned or spent Fan Coin event should create a transaction record.

Fan Score should also have a history of why it changed \- probably similar to a credit score

Ad completions and Fan Coin awards need reconciliation so users are not incorrectly paid.

Fraud control is required for reward systems.

Examples:

* duplicate reward checks  
* suspicious activity checks  
* repeated ad farming checks

Revenue planning belongs in internal business tracking, not in the user-facing app spec.

---

### **Internal Business, Cost Planning Notes. Stage-Cost Framework**

FANatical cost should be modeled by usage, not feature count.

Main cost drivers:

* users  
* actions per user  
* uploads/media  
* database reads/writes  
* ads served  
* live features  
* notifications

---

### **User Types**

**Light User**  
Reads news, completes the occasional quiz, reacts a few times, rarely uploads.

Cost: low  
Revenue: low

**Normal Fan**  
Reads news, does quizzes/streaks, comments/reacts, uploads occasional fan photos.

Cost: medium  
Revenue: medium

**Power Fan**  
Uses the app daily, completes quizzes, comments often, uploads images, votes/ranks content, joins live events, watches reward ads.

Cost: high  
Revenue: high if ads/sponsorships work  
Risk: media, moderation, notifications, and live-event spikes

---

### **Cost Buckets**

Track:

* accounts/auth  
* database  
* image storage  
* image delivery/bandwidth  
* server/API calls  
* moderation  
* notifications  
* ad system  
* analytics

Big rule:  
Photos and videos are the cost gremlins.

Cheap activity:

* text  
* quizzes  
* reactions  
* tags  
* basic rankings  
* profile fields

Expensive activity:

* photo uploads  
* video uploads  
* image delivery  
* live-event bursts  
* heavy notifications  
* moderation at scale

Media strategy:

* avoid videos early  
* compress photos  
* limit photo uploads  
* encourage photo viewing/rating/ranking instead of mass uploading  
* Encourage completing quizzes  
* Encourage COMMENTING on news \- ads in FANbase could be decent revenue stream

---

### **Revenue Notes**

Banner ads are weak.

Rewarded video is stronger.

Sponsorships and local/team deals can beat generic ads early.

Affiliate and partner offers can matter later.

Photo ranking can become a useful ad loop:

* view/rate photos  
* show ad between batches  
* continue ranking

Quiz completion could become a useful ad loop

The goal is cheap engagement around controlled media, not unlimited media uploading.

---

### **Projection Stages**

Model these stages:

* 1,000 users  
* 10,000 users  
* 50,000 users  
* 100,000 users

For each stage, estimate the user mix:

* Light Users  
* Normal Fans  
* Power Fans

Starting assumption:

* 60% Light Users  
* 30% Normal Fans  
* 10% Power Fans

Adjust once real usage data exists.

---

### **Spreadsheet Columns**

Track:

* average sessions / user / month  
* quizzes / user / month  
* comments / user / month  
* reactions / user / month  
* photos uploaded / user / month  
* photo ratings / user / month  
* photo views / user / month  
* ad views / user / month  
* monthly backend cost  
* monthly media cost  
* monthly ad revenue  
* monthly sponsorship revenue  
* net margin

---

### **Operating Question**

Can cheap engagement grow faster than expensive media costs?

Current assumption:  
Yes, if videos are avoided and photos are compressed, limited, moderated, and used to drive rating/ranking engagement.

Build rule:  
Cheap engagement should grow faster than expensive media usage.

---

## **8\. To-Do List**

* exact Fan Score formula  
* exact Fan Coin earning rates for ad-supported Quiz, FANbase, Photo Ranking, and other approved ad/reward flows  
* exact Low / Medium / High / Maximum ad behavior  
* whether Fan Coins expire  
* whether Fan Score changes over time  
* where future redemption lives  
* what rewards actually exist — gift cards, partner rewards, merchandise, discounts, or other redemption options  
* daily/weekly Fan Coin earning caps  
* fraud review thresholds  
* ad providers  
* whether users can earn Fan Coins without ads  
* exact photo batch size before ads appear  
* exact ad placement throughout the app and how it varies depending on selected ad level  
* exact internal revenue spreadsheet assumptions  
* exact full membership price and membership activation rules  
* exact default ad level/frequency for basic users needed to reasonably cover their operating cost

● Annual Reader Survey / Journalism Support Program — use prize draws and journalism awards to gather source ratings, discovery attribution, reader-request support for participating publishers/journalists, and fund recognition/cash prizes from FANatical revenue

# Backend scale up

# **Backend / Data / Scale / Safety / Admin**

## **1\. Purpose**

Backend / Data / Scale / Safety / Admin defines how FANatical stores data, handles user actions, controls expensive features, moderates community content, supports growth, and gives admins the tools needed to manage the app.

This is not a normal user-facing feature page.

It supports every major part of the app:

* News  
* FANbase  
* Cheer  
* Quiz  
* Profile  
* Rewards / Ads / Revenue  
* Notifications  
* Admin tools

Core principle:

Make user actions feel instant.  
Make heavy backend work happen later in organized chunks.

The app should avoid unnecessary cost, abuse, spam, moderation chaos, and scaling problems.

---

### **Backend Crash Course**

**Server** \= runs app logic  
Example: save this comment, calculate points, send notification.

**Database** \= stores the truth  
Example: users, profiles, quiz scores, comments, rankings, Fan Score, Fan Coins.

**Storage** \= stores media  
Example: photos, avatars, thumbnails, graphics.

**CDN** \= delivers images/assets faster  
Example: loads profile photos and app graphics without hammering the main server.

**Cache** \= temporary shortcut for popular or repeated data  
Example: top Oilers photos today saved temporarily instead of recalculated every tap.

**Batch** \= process groups later, not instantly  
Example: update rankings overnight instead of after every rating.

**Queue** \= waiting line for heavy jobs  
Example: image processing, moderation scans, notifications.

**Rate limit** \= stops spam and overload  
Example: max uploads/hour, max reactions/second.

**Upload limit** \= controls file size/type  
Example: photo size limits, approved image types, no early video uploads.

**API** \= pathway frontend uses to talk to backend  
Example: app asks backend to load quiz, save reaction, or submit vote.

**Auth** \= login/account identity  
Example: user account, permissions, profile ownership.

**Moderation** \= checks content/users  
Example: reports, spam, abusive content, photo review.

**Notifications** \= alerts, reminders, push messages  
Example: an in-app alert that a requested News identity is now available, or an approved major-event reminder.

**Analytics** \= tracks usage, retention, revenue, and cost drivers.

**Scaling** \= app still works when traffic explodes.

---

## **2\. Main Areas / Systems**

Backend contains these main systems:

**Accounts / Auth / Membership**

User accounts, login, identity, permissions, profile ownership, and Basic / Full Member status

**Database**  
Stores users, teams, sources, quizzes, comments, photos, ratings, rankings, cheers, rewards, and activity history.

**Media Storage**  
Stores profile photos, FANbase photos, thumbnails, avatars, and approved graphics.

**API / Server Logic**  
Handles app actions like saving comments, submitting quiz answers, rating photos, joining events, and loading feeds.

**Cache**  
Stores commonly loaded data so the app does not rebuild the same thing every time.

**Batch Jobs**  
Runs scheduled calculations such as rankings, badges, leaderboards, feed updates, summaries, and difficulty calibration.

**Queues**  
Handles slower work such as image processing, moderation scans, notifications, badge updates, and reward reconciliation.

**Moderation / Safety**  
Controls user content, reports, spam, abuse, photo review, and community safety.

**Notifications**  
Handles limited, intentional alerts. The currently approved News notification is an in-app alert when Resolution makes a fan-requested News identity available; broader News notification channels and triggers require separate approval.

**Admin Tools**  
Internal controls for reviewing reports, managing the News catalog and Resolution work, approving quizzes, managing cheers, handling users, and checking app health

**Membership / Entitlements**

Tracks Basic or Full Member status, membership activation/expiry where applicable, access to Ad Intensity controls, and Fan Coin earning eligibility.

**Analytics / Cost Tracking**  
Tracks usage, cost drivers, ad performance, media usage, and growth risks.

---

## **3\. User / System Flow**

### **Basic Action Flow**

User takes an action  
App sends action to backend  
Backend validates action  
Backend saves action  
App updates quickly  
Expensive follow-up work happens later if needed

Examples:

* user submits quiz answer  
* user reacts to a photo  
* user comments in FANbase  
* user votes for a Cheer prompt  
* eligible Full Member changes Ad Intensity

---

### **Media Upload Flow**

User uploads a photo  
Backend checks file size/type  
Photo is compressed  
Thumbnail is created  
Moderation scan/review runs where needed  
Photo becomes visible where allowed  
Ranking/reaction systems can use the photo

Videos are avoided until the business can afford them.

FANatical should not become a generic “I was at the game” photo dump.

Those photos already belong on Instagram, Facebook, Snapchat, or personal feeds.

FANatical photos should be intentional and category-based.

Primary photo categories:

* Game Face  
* Fan Cave  
* Memorabilia

The valuable loop is:

* controlled photo upload  
* users view photos  
* users rate/rank/react positively  
* rankings update later  
* badges/status appear after ranking cycle

---

### **Ranking Flow**

User rates/reacts/votes  
Backend saves the action immediately  
Public count updates where needed  
Rankings update in scheduled batches  
Badges update after ranking cycle

Preferred ranking model:

* daily / overnight ranking updates  
* users wake up and see how ranks changed  
* photo ranks, badges, Top 10 / Top 50 / Top 100, and category movement update after the cycle

Ranking calculations should not rerun from scratch after every single vote.

Do not run heavy ranking calculations during live events.

---

### **Notification Flow**

Approved user, Resolution, or scheduled-event action creates a notification trigger
Backend checks user settings  
Backend checks rate limits  
Notification enters queue  
Notification sends only when useful

Notifications should be limited and intentional.

Currently approved News notification use case:

* requested Author, podcast Show, or organizational contributor becomes available through Resolution; notify the requesting fan in-app

Other approved application notification use cases may include:

* important event reminders where approved

Do not send notifications by default for:

* every comment  
* every reaction  
* every rating  
* routine ranking movement  
* low-value engagement loops

---

### **Live Event Flow**

User joins live event  
Backend records event/check-in state  
User selects seating/area where needed  
Backend loads active prompt state  
Users vote or participate  
Backend updates lightweight live state  
Heavy calculations wait until later

Live moments are for coordination, not calculation.

---

### **Admin Flow**

Admin opens internal tools  
Admin reviews reports, News catalog/Resolution work, quizzes, photos, cheers, or user issues
Admin reviews reports, News catalog/Resolution work, quizzes, photos, cheers, or user issues.

Admin approves or rejects content where pre-review applies, and can hide, flag, remove, or escalate user content through moderation where appropriate.

System records admin action history

---

## **4\. UI / Admin Components**

This section mostly supports backend systems, but it needs internal admin screens.

Admin components:

* user lookup  
* reported content queue  
* photo review queue  
* quiz approval queue  
* Cheer moderation/management   
* venue mapping / Seat Resolver management
* News catalog / Resolution manager
* event manager  
* notification manager  
* reward/ad event review  
* moderation history  
* basic analytics dashboard  
* cost/usage dashboard

Admin dashboard should show:

* active users  
* uploads  
* comments  
* reactions  
* reports  
* storage use  
* bandwidth use  
* notification volume  
* ad/reward activity  
* backend errors

User-facing components are defined in their own feature sections.

---

## **5\. Rules**

Membership / Rewards Eligibility Rule

Basic users use FANatical’s default ad level and cannot change Ad Intensity. Full Members can select their own Ad Intensity. Only Full Members are eligible to earn Fan Coins.

Membership status and Fan Coin eligibility must be enforced by the backend, not only hidden or disabled in the frontend

For every feature, ask:

**DATA**  
What information has to be stored?

**LOAD**  
How often will users read or write this?

**LIVE OR BATCH**  
Does it need to update instantly, delayed, hourly, daily, or overnight?

**COST**  
Is it cheap text/action data or expensive media/live/notification work?

**RISK**  
Can this be abused, spammed, botted, crashed, copyrighted, or made expensive?

---

### **Immediate Actions**

These should feel instant:

* login  
* loading profile  
* submitting quiz answer  
* saving quiz attempt  
* posting comment  
* reacting  
* rating photo  
* voting on Cheer prompt  
* joining event  
* changing settings

---

### **Batch Actions**

These update later:

* rankings  
* leaderboards  
* badges  
* trophies  
* difficulty calibration  
* trending threads  
* top photos  
* Fan Score summaries  
* feed refreshes

Preferred batch timing:

* rankings update overnight/daily  
* badges update after ranking cycle  
* summaries update outside live-event windows

---

### **Queued Actions**

These run in the background:

* image compression  
* thumbnail creation  
* moderation scan  
* notification delivery  
* reward reconciliation  
* abuse review  
* badge updates  
* feed refresh jobs

---

### **Cost Rules**

Text is cheap.

Quizzes are cheap.

Reactions are cheap.

Tags are cheap.

Basic rankings are cheap when batched.

Photos are expensive.

Videos are very expensive.

Live-event spikes can be expensive.

Notifications can become expensive and annoying if uncontrolled.

Build rule:  
Cheap engagement should grow faster than expensive media usage.

---

### **Media Rules**

Photo uploads are compressed.

Photo uploads are limited.

Photo uploads are categorized.

Videos are avoided early.

The app should encourage photo viewing, rating, ranking, and reacting more than mass uploading.

---

### **Notification Rules**

Notifications are limited and intentional.

The current News requirement is the in-app request-resolution notification. Breaking-News, email, browser, and push delivery are not approved by this News authority.

Routine comments, reactions, ratings, and ranking movement do not create default notifications.

Users can choose more notification types later if settings support it.

---

### **Safety Rules**

User-created content needs moderation.

Reports need admin review.

Spam needs rate limits.

Reward systems need fraud checks.

Media uploads need limits.

Admin actions need history.

---

## **6\. Data / Labels / Filters**

Core backend data:

* Users  
* membership status  
* membership activation / expiry where applicable  
* Fan Coin earning eligibility  
* profiles  
* teams  
* sports  
* leagues  
* sources  
* news items  
* quizzes  
* quiz attempts  
* FANbase threads  
* comments  
* reactions  
* photos  
* ratings  
* rankings  
* cheers  
* events  
* notifications  
* Fan Score events  
* Fan Coin transactions  
* reports  
* moderation actions  
* admin actions

Common labels:

* user ID  
* team  
* sport  
* league  
* source  
* content type  
* created time  
* status  
* visibility  
* approval status  
* report status

Content statuses:

* draft  
* pending review  
* approved  
* rejected  
* hidden  
* flagged  
* archived

Visibility statuses:

* public  
* private  
* event-only  
* group-only

Moderation statuses:

* clean  
* reported  
* under review  
* actioned  
* escalated

---

## **7\. Backend / Scale Notes**

### **Feature Load Map**

**News**  
Data: canonical News Items and manifestations, News identities, follows, classifications, discussions, and FANatical-generated outbound opens
Scale: high reads with durable ingestion and comparatively lower direct fan-write volume
Backend move: query/cache chronological eligible feeds and monitor configured endpoints through durable work
Notification scope: in-app request-resolution notification only unless later News notification behavior is separately approved

**Quiz**  
Data: questions, answers, scores, attempts  
Scale: frequent and cheap  
Backend move: instant scores, batch leaderboards and difficulty calibration

**Reactions / Comments**  
Data: user, post, reaction/comment  
Scale: medium-high  
Backend move: instant save, cache counts  
Notification priority: low by default

**Rankings / Badges**  
Data: scores, votes, category, rank, badge status  
Scale: calculation-heavy  
Backend move: batch overnight/daily  
Live-event rule: never recalculate during live moments

**Fan Photos**  
Data: image, user, team, category, rating, ranking status  
Scale: moderate uploads, high viewing/rating potential  
Backend move: compress, limit, categorize, queue moderation where needed  
Business move: encourage viewing/rating/ranking, not mass uploads

**Videos**  
Data: huge files  
Scale: expensive chaos  
Backend move: avoid until the business can afford them

**Prime Fan Animations**  
Data: app assets  
Scale: cheap if preloaded  
Backend move: CDN/cache

**Cheer / Live Events**  
Data: prebuilt cheer files, timing triggers, event state, votes  
Scale: stadium-sized bursts  
Backend move: preload assets, use lightweight live state, server sends “start now”

**Profile**  
Data: user identity, fan photos, stats, trophies, moments  
Scale: moderate reads/writes  
Backend move: separate public profile data from private account/settings data

**Rewards / Ads / Revenue**  
Data: Fan Score events, Fan Coin transactions, membership status, Fan Coin eligibility, Ad Intensity, ad/reward events

Backend move: enforce membership eligibility, use ledger-style Fan Coin tracking, and maintain audit history

**Notifications**  
Data: user settings, notification type, trigger, delivery status  
Scale: controlled intentionally  
Backend move: queue delivery, rate limit, avoid spam

---

### **Live / Batch / Queue Summary**

Live/immediate:

* login  
* posting comments  
* giving reactions  
* quiz answer submission  
* basic feed loading  
* Cheer voting/check-in  
* photo rating save

Batch/cache:

* rankings  
* leaderboards  
* trending posts  
* Fan Score summaries  
* reward calculations  
* top 10 / top 50 / top 100 badges  
* quiz difficulty calibration

Queue:

* image processing  
* moderation scans  
* notifications  
* badge updates  
* feed refresh jobs  
* reward reconciliation

---

### **Scaling Priorities**

Early priority:

* clean data structure  
* controlled media uploads  
* basic moderation  
* basic admin tools  
* cached feeds  
* batch rankings  
* simple analytics  
* limited notifications

Later priority:

* stronger search  
* advanced recommendations  
* larger event scaling  
* deeper moderation tools  
* more automation  
* advanced sponsor/ad reporting  
* richer admin controls

---

### **Rate Limits**

Rate limits should exist for:

* comments  
* reactions  
* photo uploads  
* ratings  
* reports  
* Cheer votes  
* reward actions  
* login/security events

Example limits:

* max photo uploads per hour/day  
* max reactions per second  
* max reports per user/day  
* max Cheer votes per prompt  
* max reward actions per day

Exact values are open decisions.

---

### **Admin Must-Haves**

Before real public growth, admins need:

* report review  
* user search  
* content hide/remove tools  
* quiz approval  
* cheer moderation/managment  
* authenticated venue mapping / Seat Resolver management
* source management  
* photo moderation  
* basic usage dashboard  
* basic cost dashboard

---

## **8\. To-Do List**

* backend platform  
* database structure  
* auth provider  
* media storage provider  
* image size limits  
* upload limits  
* notification provider  
* moderation tooling  
* admin dashboard scope  
* report escalation rules  
* batch ranking schedule  
* leaderboard update schedule  
* cache strategy  
* rate limit values  
* data retention rules  
* backup/export plan  
* analytics provider  
* cost dashboard structure  
* exact default notification settings  
* what must be built before public launch  
* exact membership/payment provider  
* membership activation, renewal, expiry, and cancellation handling  
* exact backend enforcement of Basic vs Full Member permissions and Fan Coin eligibility

# Prime fan

PRIME FAN \- MASTER IDEA DUMP

CORE CHARACTER

Prime Fan \= first FANatical fan/user

Transformer-inspired sports superfan robot

Oversized helmet/chibi proportions

Huge expressive helmet \+ smaller athletic body

Identity hidden so anyone can “be” Prime Fan

Can appear at real events as community ambassador/mascot

Cartoon version integrated directly into app UI

Functional mascot, not just branding

CHARACTER STYLE

Giant helmet \= emotional expression engine

LED/visor eyes

Hyper expressive movements

Fast, simple cartoon animation style

2D animation preferred initially

Rigged puppet-style animation for efficiency

Meme-friendly personality

Sports dad energy

Emotional, dramatic, funny, relatable

PRIME FAN FAMILY/WORLD

Mrs. Prime Fan

Tiny hat/toque on helmet

Dry humor

Calls out Prime Fan stupidity

“You can’t do that here”

Prime Fan kid(s)

Wants toys/merch

Gets homework blasted at him

Learns chants

Sports family dynamic

Prime Fan universe \= recurring cast possible later

UI / APP INTEGRATION

Runs across home screen pointing at features

Tutorial/demo guide character

Explains app systems naturally

Appears in onboarding

Empty-state interactions

Loading screen animations

Quiz countdown animations

Daily streak reminders

Cheer/tutorial demonstrations

Crowd-light synchronization demos

Points/reward explanation videos

EXPRESSIONS / EMOTES

PHASE 1 STATIC

Happy

Angry

Sad

Shocked

Confused

Hype

Crying

Facepalm

Locked-in/focus mode

Smug

Rage mode

Celebration mode

Panic mode

Disappointed mode

Suspicious side-eye

Referee rage

Playoff heartbreak

Overtime stress

Victory insanity

PHASE 2 ANIMATED

Visor blinking

Slow helmet tilt

Rapid blinking panic

Helmet droop sadness

Visor flare hype

Tiny shrug

Double fist pump

Controller smash

Foam finger deploy

Jersey transformation

Arm cannon transformation

Rally towel spin

Slow dramatic turn

Target-lock zoom

TRANSFORM FEATURES

Foam finger deploys from arm

T-shirt cannon arm

Beer/snack compartment

Auto-switching jerseys

Visor analysis mode

Rage mode transformations

Celebration mode

Rally towel launcher

LED color changes

Team color transformation packs

Sport-specific gear loadouts

PROMOTIONAL SKIT IDEAS

“I’m not doomscrolling, I’m earning points”

Mrs. Prime Fan catches Prime Fan scrolling sports news

“That hat? Paid for with FAN Coins.”

Prime Fan overreacting to preseason games

Pretending losses don’t hurt

Financially responsible mode failing during playoffs

Sneaking sports merch purchases

Teaching chants dramatically

Watching games with absurd emotional swings

Trying not to rage at referees

REFEREE RAGE IDEAS

Bad call happens

Prime Fan slowly turns

Visor narrows

Predator-style target lock

Ref name highlighted in crowd

Mrs. Prime Fan: “Don’t even think about it.”

Arm cannon starts charging

Screen cuts before chaos

EVENT / COMMUNITY IDEAS

Real-life Prime Fan appearances

“Prime Fan spotted at Gate 3”

Fan check-ins/scans

Photo opportunities

Hype leader at games/events

Cheer demonstrations

Crowd-light synchronization leader

Multiple team variants

Different jersey/loadout versions

Potential college/playoff viral mascot

FUTURE SCALING

PHASE 1

Static artwork

Emotes/stickers

Basic UI helper

PHASE 2

Motion graphics

Short looping animations

Social media clips

PHASE 3

Recurring animated shorts

Storyline/world-building

Promotional skits

PHASE 4

Fully interactive in-app assistant

Reactive UI animations

Personalized fan interactions

Event integration/community system

IMPORTANT OVERALL IDEA

Prime Fan should feel like:

the voice of sports fans

emotionally unstable but lovable

community-first

memeable

authentic

hype

chaotic good

NOT corporate/polished

“Sports apps are spreadsheets in jerseys. FANatical feels alive.”

# Hiring buildup

Honestly, that sounds like a pretty rational plan now. You’ve gone from: “idea tornado” to “actual startup sequencing.” 🌪️➡️🏗️

And I think your core insight is correct:

You are no longer trying to answer: “Can this app exist?”

You’re trying to answer: “Can this architecture survive growth?”

Very different question.

Your likely flow now sounds like:

1\. Build aggressively with AI tools

Lovable

V0

ChatGPT/OpenClaw

prototypes

functional systems

2\. Compare outputs

see what each tool does well

compare architecture/style

identify weak spots

merge best ideas

3\. Bring in technical lead/architect NOT primarily to: “write every button.”

Primarily to:

evaluate scalability

validate architecture

standardize systems

secure backend

prevent technical debt disasters

decide what gets rebuilt vs kept

4\. Then scale team selectively ONLY after:

traction

bottlenecks

real usage

real pain points

That’s a much smarter sequence than hiring a giant expensive team before you even know where the real problems are.

And honestly? You’re also correct that most of FANatical’s individual FEATURES are not technically revolutionary.

The challenge is:

integration

performance

scaling

community systems

emotional design

execution quality

Which is actually good news.

The biggest risk for you probably isn’t: “can this be built?”

It’s:

maintaining focus

avoiding feature overload

controlling technical complexity

building community momentum fast enough

That’s a WAY more solvable problem than inventing impossible technology.

FIRST 5 (REALISTIC EARLY FANATICAL TEAM)

1\. Technical Lead / Architecture Owner

Your “Woz.”

Role:

reviews AI-generated/outsourced code

owns scalability direction

backend architecture

security

long-term technical decisions

decides what survives/rebuilds

MOST important long-term hire.

\---

2\. Growth \+ Sales \+ Partnerships Hybrid

Early momentum machine.

Role:

bars/restaurants

campus outreach

sponsorships

ad deals

local partnerships

event coordination

brand relationships

Probably merged roles early.

\---

3\. Frontend / Product Developer

Builds features/UI fast.

Role:

app polish

frontend systems

profiles

quiz flows

interactions

responsiveness

implementing product ideas rapidly

Could start outsourced/contracted before becoming permanent.

\---

4\. Prime Fan / Content / Motion Creator

Massive emotional leverage role.

Role:

Prime Fan animations

social clips

onboarding content

memes/promos

mascot personality

motion graphics

This role makes FANatical feel alive instead of corporate.

\---

5\. Community / Social Manager

Sports internet brain.

Role:

social posting

moderation culture

community engagement

meme awareness

clipping moments

hype cycles

fan interaction

Very important for sports/community apps.

\---

NEXT 5 (AFTER TRACTION)

6\. Backend Infrastructure Engineer

Dedicated scaling person.

Role:

databases

caching

queues

notifications

optimization

performance

reliability

May initially overlap with \#1.

\---

7\. Monetization / Ad Operations Specialist

Once scale exists.

Role:

rewarded ads

CPM optimization

sponsorship inventory

ad pacing

revenue systems

Could initially overlap with \#2.

\---

8\. UI/UX \+ Brand Designer

Visual consistency guardian.

Role:

app cohesion

typography

merch

event materials

design systems

usability refinement

You already naturally handle some UX thinking yourself.

\---

9\. Event / Campus Activation Lead

Once physical growth starts.

Role:

Prime Fan appearances

tailgates

contests

stadium/campus logistics

ambassador programs

This becomes huge IF the community side takes off.

\---

10\. Trust & Safety / Moderation Systems

The “prevent chaos” role.

Role:

moderation tooling

reporting systems

anti-spam

escalation handling

policy systems

Not exciting… until you desperately need it. 😆

Honestly though? Your TRUE early core may realistically just be:

You

Technical owner

Growth/sales person

Flexible frontend/product dev

Motion/content person

That’s already enough to build serious momentum if the concept hits.

# Cross Impact Notes

# **Cross-Impact Notes**

Purpose:  
Track only what each reviewed feature affects outside itself.

For each reviewed section, capture:

**App Structure impact**  
Changes to navigation, layout, page flow, team context, filters, or shared UI.

**Backend impact**  
Changes to storage, scale, batching, queues, moderation, notifications, admin tools, or cost.

**Tags / Data impact**  
Tags, labels, IDs, categories, filters, or data fields needed to connect the app properly.

**Other Section impact**  
Any direct connection to another feature section.

Format:  
Section affected — impact

Example:  
FANbase — Profile Fan Photos also appear in FANbase rankings and rating feeds.  
Rewards — Quiz performance may affect Fan Score, while ad flow may affect Fan Coins.  
Backend — Photo rankings require daily/overnight batch updates.

---

**Cross-Impact Notes**

Purpose: Track only what each reviewed feature affects outside itself.

**News System**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:

**FANbase / Community System**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:

**Cheer / Live Events**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:

**Quiz System**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:

**Profile / Fan Identity**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:

**Rewards / Ads / Revenue**

App Structure impact:

Backend impact:

Tags / Data impact:

Other Section impact:
