-- Add room layout fields to rooms table
-- Run this migration to add room layout configuration

ALTER TABLE public.rooms
ADD COLUMN IF NOT EXISTS rows_count INTEGER,
ADD COLUMN IF NOT EXISTS seats_per_row INTEGER,
ADD COLUMN IF NOT EXISTS layout_config JSONB;

-- Add comment for documentation
COMMENT ON COLUMN public.rooms.rows_count IS 'Number of rows/benches in the room';
COMMENT ON COLUMN public.rooms.seats_per_row IS 'Number of seats per row/bench';
COMMENT ON COLUMN public.rooms.layout_config IS 'Additional layout configuration (JSON)';

