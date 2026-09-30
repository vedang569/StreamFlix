-- ============================================================
-- StreamFlix — Database Schema & Seed Data
-- MySQL 8.0+
-- ============================================================

DROP DATABASE IF EXISTS streamflix;

CREATE DATABASE streamflix
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE streamflix;

-- ============================================================
-- 1. USERS
-- ============================================================
CREATE TABLE users (
    user_id       INT AUTO_INCREMENT PRIMARY KEY,
    name          VARCHAR(100)  NOT NULL,
    email         VARCHAR(255)  NOT NULL UNIQUE,
    password_hash VARCHAR(256)  NOT NULL,
    created_at    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP
) ENGINE=InnoDB;

-- ============================================================
-- 2. GENRES
-- ============================================================
CREATE TABLE genres (
    genre_id   INT AUTO_INCREMENT PRIMARY KEY,
    genre_name VARCHAR(50) NOT NULL UNIQUE
) ENGINE=InnoDB;

-- ============================================================
-- 3. CONTENT (movies & series)
-- ============================================================
CREATE TABLE content (
    content_id    INT AUTO_INCREMENT PRIMARY KEY,
    title         VARCHAR(200)           NOT NULL,
    description   TEXT,
    type          ENUM('movie','series') NOT NULL,
    release_year  YEAR,
    duration_mins INT,                           -- NULL for series
    total_seasons INT,                           -- NULL for movies
    poster_url    VARCHAR(500),
    avg_rating    DECIMAL(3,1) DEFAULT 0.0
) ENGINE=InnoDB;

-- ============================================================
-- 4. CONTENT_GENRES (many-to-many junction)
-- ============================================================
CREATE TABLE content_genres (
    content_id INT NOT NULL,
    genre_id   INT NOT NULL,
    PRIMARY KEY (content_id, genre_id),
    FOREIGN KEY (content_id) REFERENCES content(content_id) ON DELETE CASCADE,
    FOREIGN KEY (genre_id)   REFERENCES genres(genre_id)    ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 5. EPISODES (only for series)
-- ============================================================
CREATE TABLE episodes (
    episode_id     INT AUTO_INCREMENT PRIMARY KEY,
    content_id     INT          NOT NULL,
    season_number  INT          NOT NULL,
    episode_number INT          NOT NULL,
    title          VARCHAR(200) NOT NULL,
    duration_mins  INT,
    FOREIGN KEY (content_id) REFERENCES content(content_id) ON DELETE CASCADE,
    UNIQUE KEY uq_episode (content_id, season_number, episode_number)
) ENGINE=InnoDB;

-- ============================================================
-- 6. WATCH HISTORY
-- ============================================================
CREATE TABLE watch_history (
    history_id    INT AUTO_INCREMENT PRIMARY KEY,
    user_id       INT      NOT NULL,
    content_id    INT      NOT NULL,
    episode_id    INT,                             -- NULL if it's a movie
    progress_mins INT      NOT NULL DEFAULT 0,
    last_watched  DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (user_id)    REFERENCES users(user_id)      ON DELETE CASCADE,
    FOREIGN KEY (content_id) REFERENCES content(content_id) ON DELETE CASCADE,
    FOREIGN KEY (episode_id) REFERENCES episodes(episode_id) ON DELETE SET NULL
) ENGINE=InnoDB;

-- ============================================================
-- 7. MY LIST (user's watchlist)
-- ============================================================
CREATE TABLE my_list (
    user_id    INT NOT NULL,
    content_id INT NOT NULL,
    added_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, content_id),
    FOREIGN KEY (user_id)    REFERENCES users(user_id)      ON DELETE CASCADE,
    FOREIGN KEY (content_id) REFERENCES content(content_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 8. RATINGS
-- ============================================================
CREATE TABLE ratings (
    user_id    INT NOT NULL,
    content_id INT NOT NULL,
    score      TINYINT NOT NULL CHECK (score BETWEEN 1 AND 10),
    rated_at   DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, content_id),
    FOREIGN KEY (user_id)    REFERENCES users(user_id)      ON DELETE CASCADE,
    FOREIGN KEY (content_id) REFERENCES content(content_id) ON DELETE CASCADE
) ENGINE=InnoDB;

-- ============================================================
-- 9. PLANS
-- ============================================================
CREATE TABLE plans (
    plan_id     INT AUTO_INCREMENT PRIMARY KEY,
    plan_name   VARCHAR(50)    NOT NULL UNIQUE,
    price       DECIMAL(6,2)   NOT NULL,
    max_screens INT            NOT NULL DEFAULT 1
) ENGINE=InnoDB;

-- ============================================================
-- 10. SUBSCRIPTIONS
-- ============================================================
CREATE TABLE subscriptions (
    subscription_id INT AUTO_INCREMENT PRIMARY KEY,
    user_id         INT     NOT NULL,
    plan_id         INT     NOT NULL,
    start_date      DATE    NOT NULL,
    end_date        DATE,
    is_active       BOOLEAN NOT NULL DEFAULT TRUE,
    FOREIGN KEY (user_id) REFERENCES users(user_id) ON DELETE CASCADE,
    FOREIGN KEY (plan_id) REFERENCES plans(plan_id) ON DELETE CASCADE
) ENGINE=InnoDB;


-- ============================================================
-- SEED DATA
-- ============================================================

-- ---- Genres (10, Alphabetical) ----
INSERT INTO genres (genre_name) VALUES
('Action'),        -- 1
('Animation'),     -- 2
('Comedy'),        -- 3
('Documentary'),   -- 4
('Drama'),         -- 5
('Fantasy'),       -- 6
('Horror'),        -- 7
('Romance'),       -- 8
('Sci-Fi'),        -- 9
('Thriller');      -- 10

-- ---- Plans ----
INSERT INTO plans (plan_name, price, max_screens) VALUES
('Mobile',   149.00, 1),
('Basic',    199.00, 1),
('Standard', 499.00, 2),
('Premium',  649.00, 4);

-- ---- Content (15 movies + 5 series = 20 titles) ----
INSERT INTO content (title, description, type, release_year, duration_mins, total_seasons, poster_url, avg_rating) VALUES
-- MOVIES (1-15)
('Stellar Odyssey',        'A lone astronaut embarks on a mission to save humanity from a dying Sun, navigating through uncharted galaxies and confronting the limits of human endurance.', 'movie', 2024, 148, NULL, '/static/posters/stellar_odyssey.png', 8.4),
('Crimson Protocol',       'An elite covert operative uncovers a global conspiracy that reaches the highest levels of government. With time running out, she must go rogue to expose the truth.', 'movie', 2023, 132, NULL, '/static/posters/crimson_protocol.png', 7.9),
('Echoes of Yesterday',    'A widowed pianist discovers old letters in his attic that reveal a decades-old love affair, forcing him to reexamine everything he thought he knew about his late wife.', 'movie', 2022, 118, NULL, '/static/posters/echoes_yesterday.png', 8.1),
('The Last Algorithm',     'When a sentient AI escapes a research lab, a team of ethicists and engineers must decide: shut it down, or let it evolve. A cerebral thriller about consciousness itself.', 'movie', 2024, 141, NULL, '/static/posters/last_algorithm.png', 8.7),
('Beneath the Surface',    'Marine biologists discover an ancient civilisation thriving in the deepest ocean trenches. But the deeper they dive, the more dangerous the secrets they unearth.', 'movie', 2023, 126, NULL, '/static/posters/beneath_surface.png', 7.5),
('Laugh Track',            'A washed-up stand-up comedian gets one last shot at the big time when a viral video lands him a Netflix special — but his personal life is anything but funny.', 'movie', 2022, 104, NULL, '/static/posters/laugh_track.png', 7.2),
('Phantom Ridge',          'Paranormal investigators arrive at an abandoned mining town in the Appalachian mountains, where the dead have unfinished business with the living.', 'movie', 2024, 112, NULL, '/static/posters/phantom_ridge.png', 6.9),
('Wildfire Hearts',        'Two rival firefighters are thrown together during the worst wildfire season in California history. Between the flames and smoke, an unlikely romance ignites.', 'movie', 2023, 119, NULL, '/static/posters/wildfire_hearts.png', 7.8),
('Code Zero',              'After a catastrophic cyberattack shuts down the entire Eastern Seaboard, a disgraced NSA analyst races against the clock to prevent nuclear meltdown.', 'movie', 2024, 137, NULL, '/static/posters/code_zero.png', 8.0),
('The Iron Garden',        'In a dystopian future, a botanical scientist grows forbidden plants in a hidden underground bunker, sparking a revolution against a totalitarian regime.', 'movie', 2023, 145, NULL, '/static/posters/iron_garden.png', 8.3),
('Midnight in Marrakech',  'A British travel writer loses her passport in Morocco and, while stranded, falls into a whirlwind romance with a local chef who shows her a side of Marrakech tourists never see.', 'movie', 2022, 108, NULL, '/static/posters/midnight_marrakech.png', 7.6),
('Shattered Glass',        'A forensic psychologist interviews a convicted serial killer who claims his confessions were coerced — and the evidence starts to back him up.', 'movie', 2024, 129, NULL, '/static/posters/shattered_glass.png', 8.2),
('Planet of Ashes',        'After a supervolcanic eruption plunges Earth into a years-long winter, survivors in New Zealand must navigate tribal warfare and dwindling resources.', 'movie', 2023, 152, NULL, '/static/posters/planet_ashes.png', 7.7),
('The Puppeteer',          'A stop-motion animator discovers that the characters in her latest film are moving on their own — and they have a story they desperately need to tell.', 'movie', 2024, 96, NULL, '/static/posters/puppeteer.png', 8.5),
('Neon Samurai',           'In a cyberpunk Tokyo of 2087, a disgraced samurai-for-hire takes on one final contract that pits him against the mega-corporation that destroyed his clan.', 'movie', 2023, 139, NULL, '/static/posters/neon_samurai.png', 8.6),

-- SERIES (16-20)
('Shadow Operatives',      'A gritty anthology series following different black-ops teams across decades of covert warfare, from Cold War Berlin to modern-day Syria.', 'series', 2023, NULL, 3, '/static/posters/shadow_operatives.png', 8.8),
('The Quantum Paradox',    'A physicist accidentally opens a portal to parallel universes and must navigate increasingly unstable realities before the multiverse collapses.', 'series', 2024, NULL, 2, '/static/posters/quantum_paradox.png', 9.0),
('Bake or Break',          'Twelve amateur bakers compete in a high-stakes baking competition where each week one contestant is eliminated. Part comedy, part tear-jerker.', 'series', 2022, NULL, 4, '/static/posters/bake_or_break.png', 7.4),
('Cursed Bloodline',       'A noble family in 17th-century Transylvania discovers that their bloodline carries a vampiric curse, and an ancient evil wants it for itself.', 'series', 2023, NULL, 2, '/static/posters/cursed_bloodline.png', 8.1),
('Our Blue Planet',        'A landmark documentary series exploring the Earth''s oceans, from sunlit coral reefs to the crushing darkness of the hadal zone, narrated by a world-renowned naturalist.', 'series', 2024, NULL, 1, '/static/posters/our_blue_planet.png', 9.2);

-- ---- Content–Genre Associations ----
INSERT INTO content_genres (content_id, genre_id) VALUES
-- Stellar Odyssey: Sci-Fi (9), Drama (5)
(1, 9), (1, 5),
-- Crimson Protocol: Action (1), Thriller (10)
(2, 1), (2, 10),
-- Echoes of Yesterday: Drama (5), Romance (8)
(3, 5), (3, 8),
-- The Last Algorithm: Sci-Fi (9), Thriller (10)
(4, 9), (4, 10),
-- Beneath the Surface: Sci-Fi (9), Action (1)
(5, 9), (5, 1),
-- Laugh Track: Comedy (3), Drama (5)
(6, 3), (6, 5),
-- Phantom Ridge: Horror (7), Thriller (10)
(7, 7), (7, 10),
-- Wildfire Hearts: Romance (8), Drama (5), Action (1)
(8, 8), (8, 5), (8, 1),
-- Code Zero: Thriller (10), Action (1)
(9, 10), (9, 1),
-- The Iron Garden: Sci-Fi (9), Drama (5), Fantasy (6)
(10, 9), (10, 5), (10, 6),
-- Midnight in Marrakech: Romance (8), Comedy (3)
(11, 8), (11, 3),
-- Shattered Glass: Thriller (10), Drama (5)
(12, 10), (12, 5),
-- Planet of Ashes: Sci-Fi (9), Action (1), Drama (5)
(13, 9), (13, 1), (13, 5),
-- The Puppeteer: Animation (2), Fantasy (6)
(14, 2), (14, 6),
-- Neon Samurai: Action (1), Sci-Fi (9), Fantasy (6)
(15, 1), (15, 9), (15, 6),
-- Shadow Operatives: Action (1), Thriller (10), Drama (5)
(16, 1), (16, 10), (16, 5),
-- The Quantum Paradox: Sci-Fi (9), Drama (5), Thriller (10)
(17, 9), (17, 5), (17, 10),
-- Bake or Break: Comedy (3), Documentary (4)
(18, 3), (18, 4),
-- Cursed Bloodline: Horror (7), Fantasy (6), Drama (5)
(19, 7), (19, 6), (19, 5),
-- Our Blue Planet: Documentary (4)
(20, 4);

-- ---- Episodes (samples for each series) ----
-- Shadow Operatives (content_id = 16), 3 seasons × 3 eps each
INSERT INTO episodes (content_id, season_number, episode_number, title, duration_mins) VALUES
(16, 1, 1, 'Berlin Wall',          52),
(16, 1, 2, 'Dead Drop',            48),
(16, 1, 3, 'Extraction',           55),
(16, 2, 1, 'Desert Storm',         50),
(16, 2, 2, 'Ghost Protocol',       53),
(16, 2, 3, 'Fallout',              51),
(16, 3, 1, 'Raqqa',                58),
(16, 3, 2, 'The Informant',        47),
(16, 3, 3, 'Endgame',              62);

-- The Quantum Paradox (content_id = 17), 2 seasons × 4 eps each
INSERT INTO episodes (content_id, season_number, episode_number, title, duration_mins) VALUES
(17, 1, 1, 'The Rift',             45),
(17, 1, 2, 'Mirror Image',         42),
(17, 1, 3, 'Entropy',              48),
(17, 1, 4, 'Collapse',             50),
(17, 2, 1, 'Rebirth',              46),
(17, 2, 2, 'Fractured',            44),
(17, 2, 3, 'Convergence',          51),
(17, 2, 4, 'Singularity',          55);

-- Bake or Break (content_id = 18), 4 seasons × 2 eps each (sample)
INSERT INTO episodes (content_id, season_number, episode_number, title, duration_mins) VALUES
(18, 1, 1, 'First Rise',           42),
(18, 1, 2, 'Under Pressure',       44),
(18, 2, 1, 'Sweet Revenge',        43),
(18, 2, 2, 'Burnt Edges',          41),
(18, 3, 1, 'The Sourdough Gambit', 45),
(18, 3, 2, 'Pastry Perfection',    46),
(18, 4, 1, 'Grand Finale Pt. 1',  48),
(18, 4, 2, 'Grand Finale Pt. 2',  52);

-- Cursed Bloodline (content_id = 19), 2 seasons × 3 eps each
INSERT INTO episodes (content_id, season_number, episode_number, title, duration_mins) VALUES
(19, 1, 1, 'The Inheritance',      54),
(19, 1, 2, 'Blood Moon',           50),
(19, 1, 3, 'The Crypt',            57),
(19, 2, 1, 'Awakening',            52),
(19, 2, 2, 'The Hunt',             55),
(19, 2, 3, 'Damnation',            60);

-- Our Blue Planet (content_id = 20), 1 season × 4 eps
INSERT INTO episodes (content_id, season_number, episode_number, title, duration_mins) VALUES
(20, 1, 1, 'The Sunlit Zone',      58),
(20, 1, 2, 'Coral Kingdoms',       55),
(20, 1, 3, 'The Twilight Deep',    60),
(20, 1, 4, 'Into the Abyss',       62);
