```bash
-- ============================================
-- VESAKGO FULL DATABASE SCHEMA
-- ============================================

-- ============================================
-- USERS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    role VARCHAR(50) DEFAULT 'logged',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    total_xp INTEGER DEFAULT 0,
    current_level INTEGER DEFAULT 0,
    last_login_date DATE,
    avatar_url TEXT,
    avatar_public_id TEXT,
    phone_number VARCHAR(20),
    bio TEXT,
    
    CONSTRAINT valid_email CHECK (email ~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_total_xp ON users(total_xp DESC);
CREATE INDEX IF NOT EXISTS idx_users_current_level ON users(current_level);

-- ============================================
-- EVENTS TABLE (UPDATED WITH DATE RANGE)
-- ============================================
CREATE TABLE IF NOT EXISTS events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    category VARCHAR(100) NOT NULL,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    
    -- New date/time fields
    start_date DATE NOT NULL,
    end_date DATE NOT NULL,
    start_time TIME NOT NULL,
    end_time TIME NOT NULL,
    
    -- Location fields
    location TEXT NOT NULL,
    latitude DOUBLE PRECISION NOT NULL,
    longitude DOUBLE PRECISION NOT NULL,
    district VARCHAR(100),
    province VARCHAR(100),
    
    -- Event metadata
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_by VARCHAR(255) NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Dansala specific
    food_type VARCHAR(100) DEFAULT 'none',
    
    -- Media
    image_url TEXT,
    image_public_id TEXT,
    
    -- Statistics (denormalized for performance)
    total_visits INTEGER DEFAULT 0,
    total_memories INTEGER DEFAULT 0,
    total_bookmarks INTEGER DEFAULT 0,
    
    -- Constraints
    CONSTRAINT valid_date_range CHECK (end_date >= start_date),
    CONSTRAINT valid_category CHECK (category IN (
        'තොරණ', 'දන්සල', 'ධර්ම දේශනාව', 'බැති ගී', 'කලාප', 'කූඩු ප්‍රදර්ශන', 'පෙරහැර'
    )),
    CONSTRAINT valid_food_type CHECK (
        (category = 'දන්සල' AND food_type != 'none') OR 
        (category != 'දන්සල' AND food_type = 'none')
    ),
    CONSTRAINT valid_coordinates CHECK (
        latitude BETWEEN -90 AND 90 AND 
        longitude BETWEEN -180 AND 180
    )
);

-- Indexes for events
CREATE INDEX IF NOT EXISTS idx_events_user_id ON events(user_id);
CREATE INDEX IF NOT EXISTS idx_events_category ON events(category);
CREATE INDEX IF NOT EXISTS idx_events_start_date ON events(start_date);
CREATE INDEX IF NOT EXISTS idx_events_end_date ON events(end_date);
CREATE INDEX IF NOT EXISTS idx_events_location_coords ON events(latitude, longitude);
CREATE INDEX IF NOT EXISTS idx_events_district ON events(district);
CREATE INDEX IF NOT EXISTS idx_events_province ON events(province);
CREATE INDEX IF NOT EXISTS idx_events_created_at ON events(created_at DESC);

-- Composite index for date range queries
CREATE INDEX IF NOT EXISTS idx_events_date_range ON events(start_date, end_date);

-- ============================================
-- EVENT MEMORIES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS event_memories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    experience_note TEXT NOT NULL,
    visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Media arrays (Cloudinary URLs)
    image_urls TEXT[] DEFAULT '{}',
    image_public_ids TEXT[] DEFAULT '{}',
    video_url TEXT,
    video_public_id TEXT,
    
    -- Unique constraint: one memory per user per event
    CONSTRAINT unique_user_event_memory UNIQUE (event_id, user_id)
);

-- Indexes for event_memories
CREATE INDEX IF NOT EXISTS idx_memories_event_id ON event_memories(event_id);
CREATE INDEX IF NOT EXISTS idx_memories_user_id ON event_memories(user_id);
CREATE INDEX IF NOT EXISTS idx_memories_created_at ON event_memories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_memories_visited_at ON event_memories(visited_at);

-- ============================================
-- EVENT VISITS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS event_visits (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    visited_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    has_memory BOOLEAN DEFAULT FALSE,
    
    CONSTRAINT unique_user_event_visit UNIQUE (user_id, event_id)
);

-- Indexes for event_visits
CREATE INDEX IF NOT EXISTS idx_visits_user_id ON event_visits(user_id);
CREATE INDEX IF NOT EXISTS idx_visits_event_id ON event_visits(event_id);
CREATE INDEX IF NOT EXISTS idx_visits_visited_at ON event_visits(visited_at);

-- ============================================
-- BOOKMARKS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS bookmarks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    event_id UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_user_event_bookmark UNIQUE (user_id, event_id)
);

-- Indexes for bookmarks
CREATE INDEX IF NOT EXISTS idx_bookmarks_user_id ON bookmarks(user_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_event_id ON bookmarks(event_id);
CREATE INDEX IF NOT EXISTS idx_bookmarks_created_at ON bookmarks(created_at);

-- ============================================
-- STORIES TABLE (for community stories)
-- ============================================
CREATE TABLE IF NOT EXISTS stories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    content TEXT NOT NULL,
    image_url TEXT,
    image_public_id TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    likes_count INTEGER DEFAULT 0,
    comments_count INTEGER DEFAULT 0
);

-- Indexes for stories
CREATE INDEX IF NOT EXISTS idx_stories_user_id ON stories(user_id);
CREATE INDEX IF NOT EXISTS idx_stories_created_at ON stories(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_stories_likes_count ON stories(likes_count DESC);

-- ============================================
-- STORY LIKES TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS story_likes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT unique_user_story_like UNIQUE (user_id, story_id)
);

-- Indexes for story_likes
CREATE INDEX IF NOT EXISTS idx_story_likes_user_id ON story_likes(user_id);
CREATE INDEX IF NOT EXISTS idx_story_likes_story_id ON story_likes(story_id);

-- ============================================
-- STORY COMMENTS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS story_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    story_id UUID NOT NULL REFERENCES stories(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Indexes for story_comments
CREATE INDEX IF NOT EXISTS idx_story_comments_story_id ON story_comments(story_id);
CREATE INDEX IF NOT EXISTS idx_story_comments_user_id ON story_comments(user_id);
CREATE INDEX IF NOT EXISTS idx_story_comments_created_at ON story_comments(created_at);

-- ============================================
-- NOTIFICATIONS TABLE
-- ============================================
CREATE TABLE IF NOT EXISTS notifications (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    type VARCHAR(50) DEFAULT 'info',
    is_read BOOLEAN DEFAULT FALSE,
    related_id UUID, -- Can reference event_id, memory_id, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT valid_notification_type CHECK (type IN ('event', 'memory', 'bookmark', 'xp', 'system', 'info'))
);

-- Indexes for notifications
CREATE INDEX IF NOT EXISTS idx_notifications_user_id ON notifications(user_id);
CREATE INDEX IF NOT EXISTS idx_notifications_is_read ON notifications(is_read);
CREATE INDEX IF NOT EXISTS idx_notifications_created_at ON notifications(created_at DESC);

-- ============================================
-- XP HISTORY TABLE (for tracking XP earned)
-- ============================================
CREATE TABLE IF NOT EXISTS xp_history (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    xp_amount INTEGER NOT NULL,
    reason VARCHAR(100) NOT NULL,
    related_id UUID, -- Can reference event_id, etc.
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    CONSTRAINT positive_xp CHECK (xp_amount > 0),
    CONSTRAINT valid_reason CHECK (reason IN ('event_created', 'daily_login', 'memory_added', 'share_event', 'bookmark_event', 'register_bonus'))
);

-- Indexes for xp_history
CREATE INDEX IF NOT EXISTS idx_xp_history_user_id ON xp_history(user_id);
CREATE INDEX IF NOT EXISTS idx_xp_history_created_at ON xp_history(created_at);
CREATE INDEX IF NOT EXISTS idx_xp_history_reason ON xp_history(reason);

-- ============================================
-- FUNCTIONS AND TRIGGERS
-- ============================================

-- Function to update event statistics
CREATE OR REPLACE FUNCTION update_event_stats()
RETURNS TRIGGER AS $$
BEGIN
    -- Update total_visits
    IF TG_TABLE_NAME = 'event_visits' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE events 
            SET total_visits = total_visits + 1 
            WHERE id = NEW.event_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE events 
            SET total_visits = total_visits - 1 
            WHERE id = OLD.event_id;
        END IF;
    
    -- Update total_memories
    ELSIF TG_TABLE_NAME = 'event_memories' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE events 
            SET total_memories = total_memories + 1 
            WHERE id = NEW.event_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE events 
            SET total_memories = total_memories - 1 
            WHERE id = OLD.event_id;
        END IF;
    
    -- Update total_bookmarks
    ELSIF TG_TABLE_NAME = 'bookmarks' THEN
        IF TG_OP = 'INSERT' THEN
            UPDATE events 
            SET total_bookmarks = total_bookmarks + 1 
            WHERE id = NEW.event_id;
        ELSIF TG_OP = 'DELETE' THEN
            UPDATE events 
            SET total_bookmarks = total_bookmarks - 1 
            WHERE id = OLD.event_id;
        END IF;
    END IF;
    
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for event statistics
CREATE TRIGGER trigger_update_event_visits
    AFTER INSERT OR DELETE ON event_visits
    FOR EACH ROW EXECUTE FUNCTION update_event_stats();

CREATE TRIGGER trigger_update_event_memories
    AFTER INSERT OR DELETE ON event_memories
    FOR EACH ROW EXECUTE FUNCTION update_event_stats();

CREATE TRIGGER trigger_update_event_bookmarks
    AFTER INSERT OR DELETE ON bookmarks
    FOR EACH ROW EXECUTE FUNCTION update_event_stats();

-- Function to automatically update updated_at timestamp
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for updated_at
CREATE TRIGGER trigger_update_event_memories_updated_at
    BEFORE UPDATE ON event_memories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_stories_updated_at
    BEFORE UPDATE ON stories
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER trigger_update_story_comments_updated_at
    BEFORE UPDATE ON story_comments
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

-- Function to update user level based on XP
CREATE OR REPLACE FUNCTION update_user_level()
RETURNS TRIGGER AS $$
DECLARE
    new_level INTEGER;
BEGIN
    -- Calculate level (simplified - implement your level calculation logic)
    new_level := FLOOR(POWER(NEW.total_xp / 100.0, 0.6667))::INTEGER;
    
    IF new_level != NEW.current_level THEN
        NEW.current_level := new_level;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger to auto-update user level when XP changes
CREATE TRIGGER trigger_update_user_level
    BEFORE UPDATE OF total_xp ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_user_level();

-- ============================================
-- MIGRATION FROM OLD SCHEMA (if exists)
-- ============================================

-- This section migrates existing data from the old schema
-- Run this only if you had the old schema with 'date' and 'time' columns

DO $$
BEGIN
    -- Check if old columns exist and new columns are empty
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'events' AND column_name = 'date'
    ) AND NOT EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'events' AND column_name = 'start_date'
    ) THEN
        -- Add new columns
        ALTER TABLE events ADD COLUMN start_date DATE;
        ALTER TABLE events ADD COLUMN end_date DATE;
        ALTER TABLE events ADD COLUMN start_time TIME;
        ALTER TABLE events ADD COLUMN end_time TIME;
        
        -- Migrate data
        UPDATE events 
        SET 
            start_date = date::DATE,
            end_date = date::DATE,
            start_time = time::TIME,
            end_time = time::TIME;
        
        -- Make columns NOT NULL
        ALTER TABLE events ALTER COLUMN start_date SET NOT NULL;
        ALTER TABLE events ALTER COLUMN end_date SET NOT NULL;
        ALTER TABLE events ALTER COLUMN start_time SET NOT NULL;
        ALTER TABLE events ALTER COLUMN end_time SET NOT NULL;
    END IF;
END $$;

-- ============================================
-- ROW LEVEL SECURITY (RLS) POLICIES
-- ============================================

-- Enable RLS on all tables
ALTER TABLE users ENABLE ROW LEVEL SECURITY;
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_memories ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_visits ENABLE ROW LEVEL SECURITY;
ALTER TABLE bookmarks ENABLE ROW LEVEL SECURITY;
ALTER TABLE stories ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_likes ENABLE ROW LEVEL SECURITY;
ALTER TABLE story_comments ENABLE ROW LEVEL SECURITY;
ALTER TABLE notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_history ENABLE ROW LEVEL SECURITY;

-- Users policies
CREATE POLICY users_select_policy ON users FOR SELECT USING (true);
CREATE POLICY users_update_policy ON users FOR UPDATE USING (auth.uid() = id);

-- Events policies
CREATE POLICY events_select_policy ON events FOR SELECT USING (true);
CREATE POLICY events_insert_policy ON events FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY events_update_policy ON events FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY events_delete_policy ON events FOR DELETE USING (auth.uid() = user_id);

-- Event memories policies
CREATE POLICY memories_select_policy ON event_memories FOR SELECT USING (true);
CREATE POLICY memories_insert_policy ON event_memories FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY memories_update_policy ON event_memories FOR UPDATE USING (auth.uid() = user_id);
CREATE POLICY memories_delete_policy ON event_memories FOR DELETE USING (auth.uid() = user_id);

-- Bookmarks policies
CREATE POLICY bookmarks_select_policy ON bookmarks FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY bookmarks_insert_policy ON bookmarks FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY bookmarks_delete_policy ON bookmarks FOR DELETE USING (auth.uid() = user_id);

-- ============================================
-- SAMPLE QUERIES
-- ============================================

-- Get upcoming events (today and future)
/*
SELECT * FROM events 
WHERE end_date >= CURRENT_DATE 
ORDER BY start_date ASC, start_time ASC;
*/

-- Get events on a specific date
/*
SELECT * FROM events 
WHERE start_date <= '2024-05-23' AND end_date >= '2024-05-23';
*/

-- Get events by district
/*
SELECT * FROM events 
WHERE district = 'Colombo' 
AND end_date >= CURRENT_DATE;
*/

-- Get user's memories with event details
/*
SELECT 
    em.*,
    e.title as event_title,
    e.category as event_category,
    e.location as event_location
FROM event_memories em
JOIN events e ON em.event_id = e.id
WHERE em.user_id = 'user-uuid-here'
ORDER BY em.created_at DESC;
*/

-- Get leaderboard
/*
SELECT 
    first_name,
    last_name,
    total_xp,
    current_level
FROM users
ORDER BY total_xp DESC
LIMIT 10;
*/
```