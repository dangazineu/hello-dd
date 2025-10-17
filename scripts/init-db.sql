-- PostgreSQL Initialization Script
-- This script runs when the PostgreSQL container is first created

-- Create inventory schema if it doesn't exist
CREATE SCHEMA IF NOT EXISTS inventory;

-- Set default search path
SET search_path TO inventory;

-- Products table (will be properly defined in Phase 2 with Flyway migrations)
-- This is a placeholder structure for initial development
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku VARCHAR(50) UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    description TEXT,
    category VARCHAR(100),
    stock_level INTEGER NOT NULL DEFAULT 0,
    reserved_stock INTEGER NOT NULL DEFAULT 0,
    price DECIMAL(10, 2),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    version INTEGER DEFAULT 0
);

-- Stock transactions table for audit trail
CREATE TABLE IF NOT EXISTS stock_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID NOT NULL REFERENCES products(id),
    transaction_type VARCHAR(50) NOT NULL, -- RESERVE, RELEASE, ADJUSTMENT
    quantity INTEGER NOT NULL,
    reference_id VARCHAR(255), -- Order ID or other reference
    notes TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
    expires_at TIMESTAMP WITH TIME ZONE -- For reservations
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_products_sku ON products(sku);
CREATE INDEX IF NOT EXISTS idx_products_category ON products(category);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_product_id ON stock_transactions(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_reference_id ON stock_transactions(reference_id);
CREATE INDEX IF NOT EXISTS idx_stock_transactions_expires_at ON stock_transactions(expires_at);

-- Sample seed data for development
INSERT INTO products (sku, name, description, category, stock_level, price) VALUES
    ('LAPTOP-001', 'ThinkPad X1 Carbon', 'Business laptop with 14" display', 'Electronics', 50, 1299.99),
    ('PHONE-001', 'iPhone 15 Pro', 'Latest iPhone with titanium design', 'Electronics', 100, 999.99),
    ('BOOK-001', 'Clean Code', 'A Handbook of Agile Software Craftsmanship', 'Books', 200, 45.99),
    ('CHAIR-001', 'Herman Miller Aeron', 'Ergonomic office chair', 'Furniture', 25, 1395.00),
    ('MONITOR-001', 'Dell UltraSharp 27"', '4K USB-C Hub Monitor', 'Electronics', 75, 599.99),
    ('KEYBOARD-001', 'Keychron K2', 'Wireless Mechanical Keyboard', 'Electronics', 150, 89.99),
    ('MOUSE-001', 'Logitech MX Master 3', 'Advanced Wireless Mouse', 'Electronics', 125, 99.99),
    ('DESK-001', 'Standing Desk Pro', 'Electric height-adjustable desk', 'Furniture', 30, 699.99),
    ('HEADPHONES-001', 'Sony WH-1000XM5', 'Noise Canceling Headphones', 'Electronics', 80, 399.99),
    ('WEBCAM-001', 'Logitech Brio 4K', 'Ultra HD webcam for video calls', 'Electronics', 60, 199.99)
ON CONFLICT (sku) DO NOTHING;

-- Grant permissions (for when we have specific application users)
-- GRANT ALL PRIVILEGES ON SCHEMA inventory TO app_user;
-- GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA inventory TO app_user;
-- GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA inventory TO app_user;