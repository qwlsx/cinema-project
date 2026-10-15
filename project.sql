-- Cinema project database structure
-- Database: PostgreSQL

CREATE TABLE users (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    email VARCHAR(255) NOT NULL UNIQUE,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    birth_date DATE,
    phone VARCHAR(30),
    role VARCHAR(20) NOT NULL DEFAULT 'CUSTOMER'
        CHECK (role IN ('CUSTOMER', 'CURATOR', 'ADMIN')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE movies (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    title VARCHAR(255) NOT NULL,
    original_title VARCHAR(255),
    description TEXT NOT NULL,
    duration_minutes SMALLINT NOT NULL CHECK (duration_minutes > 0),
    release_date DATE NOT NULL,
    age_rating SMALLINT NOT NULL CHECK (age_rating BETWEEN 0 AND 18),
    critics_rating NUMERIC(4,1)
        CHECK (critics_rating BETWEEN 0 AND 100),
    original_language VARCHAR(10) NOT NULL,
    trailer_url VARCHAR(500),
    poster_url VARCHAR(500),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE genres (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(80) NOT NULL UNIQUE
);

CREATE TABLE movie_genres (
    movie_id BIGINT NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    genre_id BIGINT NOT NULL REFERENCES genres(id) ON DELETE RESTRICT,
    PRIMARY KEY (movie_id, genre_id)
);

CREATE TABLE cinemas (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100) NOT NULL,
    address VARCHAR(255) NOT NULL,
    timezone VARCHAR(50) NOT NULL DEFAULT 'Europe/Tallinn',
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (name, city)
);

CREATE TABLE halls (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    cinema_id BIGINT NOT NULL REFERENCES cinemas(id) ON DELETE RESTRICT,
    name VARCHAR(80) NOT NULL,
    supported_format VARCHAR(10) NOT NULL DEFAULT '2D'
        CHECK (supported_format IN ('2D', '3D', 'IMAX')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (cinema_id, name)
);

CREATE TABLE seats (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    hall_id BIGINT NOT NULL REFERENCES halls(id) ON DELETE RESTRICT,
    row_label VARCHAR(10) NOT NULL,
    seat_number SMALLINT NOT NULL CHECK (seat_number > 0),
    seat_type VARCHAR(20) NOT NULL DEFAULT 'STANDARD'
        CHECK (seat_type IN ('STANDARD', 'PREMIUM', 'ACCESSIBLE')),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    UNIQUE (hall_id, row_label, seat_number)
);

CREATE TABLE screenings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    movie_id BIGINT NOT NULL REFERENCES movies(id) ON DELETE RESTRICT,
    hall_id BIGINT NOT NULL REFERENCES halls(id) ON DELETE RESTRICT,
    starts_at TIMESTAMPTZ NOT NULL,
    movie_format VARCHAR(10) NOT NULL
        CHECK (movie_format IN ('2D', '3D', 'IMAX')),
    audio_language VARCHAR(10) NOT NULL,
    subtitle_language VARCHAR(10),
    base_price NUMERIC(10,2) NOT NULL CHECK (base_price >= 0),
    status VARCHAR(20) NOT NULL DEFAULT 'SCHEDULED'
        CHECK (status IN ('SCHEDULED', 'CANCELLED', 'FINISHED')),
    UNIQUE (hall_id, starts_at)
);

CREATE TABLE bookings (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE RESTRICT,
    screening_id BIGINT NOT NULL REFERENCES screenings(id) ON DELETE RESTRICT,
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'PAID', 'CANCELLED', 'EXPIRED')),
    total_amount NUMERIC(10,2) NOT NULL CHECK (total_amount >= 0),
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMPTZ,
    cancelled_at TIMESTAMPTZ,
    CHECK (cancelled_at IS NULL OR status = 'CANCELLED')
);

CREATE TABLE tickets (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    screening_id BIGINT NOT NULL REFERENCES screenings(id) ON DELETE RESTRICT,
    seat_id BIGINT NOT NULL REFERENCES seats(id) ON DELETE RESTRICT,
    price NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    qr_code VARCHAR(255) NOT NULL UNIQUE,
    status VARCHAR(20) NOT NULL DEFAULT 'VALID'
        CHECK (status IN ('VALID', 'USED', 'CANCELLED')),
    issued_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UNIQUE (screening_id, seat_id)
);

CREATE TABLE payments (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    booking_id BIGINT NOT NULL REFERENCES bookings(id) ON DELETE RESTRICT,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    status VARCHAR(20) NOT NULL DEFAULT 'PENDING'
        CHECK (status IN ('PENDING', 'COMPLETED', 'FAILED', 'REFUNDED')),
    payment_method VARCHAR(30) NOT NULL,
    provider_reference VARCHAR(255) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    paid_at TIMESTAMPTZ
);

CREATE TABLE favorites (
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    movie_id BIGINT NOT NULL REFERENCES movies(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (user_id, movie_id)
);

CREATE TABLE notifications (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    booking_id BIGINT REFERENCES bookings(id) ON DELETE CASCADE,
    message TEXT NOT NULL,
    is_read BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP,
    read_at TIMESTAMPTZ
);

CREATE INDEX idx_movies_title ON movies (title);
CREATE INDEX idx_movies_filters
    ON movies (age_rating, critics_rating, original_language);
CREATE INDEX idx_screenings_movie_start
    ON screenings (movie_id, starts_at);
CREATE INDEX idx_screenings_hall_start
    ON screenings (hall_id, starts_at);
CREATE INDEX idx_bookings_user_created
    ON bookings (user_id, created_at);
CREATE INDEX idx_payments_booking
    ON payments (booking_id);
CREATE INDEX idx_notifications_user_created
    ON notifications (user_id, created_at);

