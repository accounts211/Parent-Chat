-- ============================================================
-- Parent Chat — optional seed content
-- Run this AFTER schema.sql if you want the app to feel populated on day
-- one instead of empty. Safe to skip entirely, and safe to delete later
-- (Table Editor → filter by author = 'Community Team').
-- posted_by is left NULL here since these aren't real members — that's
-- fine, the column allows it, and this script runs with full privileges
-- via the SQL Editor so RLS doesn't apply.
-- ============================================================

insert into events (title, event_date, description, town, author, discount_note) values
('Baby sensory & sign session', current_date + 3, 'Gentle music, sensory play and simple sign language for babies 0-18 months. £4, drop in.', 'Haywards Heath', 'Community Team', ''),
('NCT nearly new sale', current_date + 9, 'Buggies, clothes and toys at bargain prices — cash only, doors open 10am.', 'Lewes', 'Community Team', 'Premium members get in 30 minutes early'),
('Toddler forest school taster', current_date + 15, 'An hour of mud, sticks and streams for 2-4 year olds. Wellies essential!', 'Henfield', 'Community Team', ''),
('Rhyme time at the library', current_date + 2, 'Songs, rhymes and bubbles for under-5s. Free, no booking needed.', 'Burgess Hill', 'Community Team', ''),
('Dads & kids Saturday football', current_date + 6, 'Informal kickabout for dads/carers and children aged 4-8. All abilities.', 'Crawley', 'Community Team', ''),
('Swap & share clothing morning', current_date + 12, 'Bring outgrown kids clothes, take home what you need. Tea and coffee provided.', 'Horsham', 'Community Team', '');

insert into forum_threads (title, body, town, author) values
('Any good weaning groups near Burgess Hill?', 'Starting weaning next month and would love to meet others going through the same thing.', 'Burgess Hill', 'Freya'),
('Recommendations for a childminder in Lewes?', 'Looking for part-time care for a 2 year old, three mornings a week.', 'Lewes', 'Owen'),
('Best soft play for a 3rd birthday party?', 'Looking at somewhere in Crawley or Horsham that can host about 15 kids.', 'Crawley', 'Priya'),
('Anyone else doing dry January with a toddler at home?', 'Just checking in with fellow parents attempting it — send solidarity.', 'Haywards Heath', 'Sam');

insert into forum_replies (thread_id, who, body)
select id, 'Nadia', 'The Triangle runs a Tuesday morning one — really friendly.'
from forum_threads where title = 'Any good weaning groups near Burgess Hill?';

insert into market_listings (title, price, cond, category, description, town, author) values
('Bugaboo Bee 5 pushchair', 120, 'Good', 'Pushchairs & Travel', 'A few scuffs on the frame but folds and steers perfectly. Includes rain cover.', 'Haywards Heath', 'Claire'),
('Bundle of 6-9 month boys clothes', 15, 'Excellent', 'Clothing', 'Smoke and pet free home, mostly Next & M&S.', 'Crawley', 'Jen'),
('Wooden cot bed, converts to toddler bed', 40, 'Good', 'Nursery Furniture', 'Mattress not included. Easy self-assembly, instructions included.', 'Lewes', 'Tom'),
('Bag of assorted board books', 8, 'Well loved', 'Books', 'About 20 books, various authors, well read but all pages intact.', 'Horsham', 'Priya'),
('Silver Cross car seat, 0-13kg', 25, 'Good', 'Pushchairs & Travel', 'Within date, smoke-free home, comes with newborn insert.', 'Burgess Hill', 'Owen');
