-- ===============================================
-- MLM REFERRAL SYSTEM DATABASE SCHEMA
-- Complete PostgreSQL schema for multi-level marketing
-- ===============================================

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- ===============================================
-- CORE USER MANAGEMENT
-- ===============================================

-- Users table - Main user records
CREATE TABLE users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    username VARCHAR(50) UNIQUE NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    password_hash VARCHAR(255) NOT NULL,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    phone VARCHAR(20),
    date_of_birth DATE,
    country VARCHAR(100),
    state VARCHAR(100),
    city VARCHAR(100),
    postal_code VARCHAR(20),
    address TEXT,
    profile_image_url TEXT,
    bio TEXT,
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'pending', 'banned')),
    verification_status VARCHAR(20) DEFAULT 'unverified' CHECK (verification_status IN ('unverified', 'email_verified', 'phone_verified', 'fully_verified')),
    email_verification_token VARCHAR(255),
    phone_verification_code VARCHAR(10),
    password_reset_token VARCHAR(255),
    password_reset_expires TIMESTAMP,
    last_login TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User settings and preferences
CREATE TABLE user_settings (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    receive_email_notifications BOOLEAN DEFAULT true,
    receive_sms_notifications BOOLEAN DEFAULT false,
    receive_marketing_emails BOOLEAN DEFAULT true,
    language VARCHAR(10) DEFAULT 'en',
    timezone VARCHAR(50) DEFAULT 'UTC',
    currency VARCHAR(10) DEFAULT 'USD',
    commission_payout_method VARCHAR(20) DEFAULT 'bank_transfer' CHECK (commission_payout_method IN ('bank_transfer', 'paypal', 'crypto', 'check')),
    minimum_payout_amount DECIMAL(10,2) DEFAULT 50.00,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- REFERRAL SYSTEM CORE
-- ===============================================

-- Referral links and codes
CREATE TABLE referral_codes (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    code VARCHAR(20) UNIQUE NOT NULL,
    custom_url VARCHAR(255) UNIQUE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    expires_at TIMESTAMP,
    max_uses INTEGER,
    current_uses INTEGER DEFAULT 0,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Referral relationships (the MLM tree structure)
CREATE TABLE referrals (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    referrer_id UUID REFERENCES users(id) ON DELETE CASCADE,
    referred_id UUID REFERENCES users(id) ON DELETE CASCADE,
    referral_code_id UUID REFERENCES referral_codes(id),
    level INTEGER NOT NULL DEFAULT 1, -- 1 = direct referral, 2 = second level, etc.
    status VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'converted')),
    conversion_date TIMESTAMP,
    referral_source VARCHAR(50), -- 'website', 'social_media', 'email', 'word_of_mouth'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(referrer_id, referred_id)
);

-- ===============================================
-- COMMISSION & COMPENSATION PLAN
-- ===============================================

-- Commission plans (multiple plans can exist)
CREATE TABLE commission_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    plan_type VARCHAR(30) DEFAULT 'percentage' CHECK (plan_type IN ('percentage', 'fixed', 'hybrid')),
    
    -- Percentage-based settings
    direct_referral_rate DECIMAL(5,2) DEFAULT 10.00, -- 10%
    level_2_rate DECIMAL(5,2) DEFAULT 5.00, -- 5%
    level_3_rate DECIMAL(5,2) DEFAULT 3.00, -- 3%
    level_4_rate DECIMAL(5,2) DEFAULT 2.00, -- 2%
    level_5_rate DECIMAL(5,2) DEFAULT 1.00, -- 1%
    max_levels INTEGER DEFAULT 5,
    
    -- Fixed amount settings
    direct_referral_amount DECIMAL(10,2) DEFAULT 0.00,
    level_2_amount DECIMAL(10,2) DEFAULT 0.00,
    level_3_amount DECIMAL(10,2) DEFAULT 0.00,
    level_4_amount DECIMAL(10,2) DEFAULT 0.00,
    level_5_amount DECIMAL(10,2) DEFAULT 0.00,
    
    -- Bonus settings
    signup_bonus DECIMAL(10,2) DEFAULT 0.00,
    first_purchase_bonus DECIMAL(10,2) DEFAULT 0.00,
    monthly_volume_bonus DECIMAL(10,2) DEFAULT 0.00,
    rank_advancement_bonus DECIMAL(10,2) DEFAULT 0.00,
    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User commission plan assignments
CREATE TABLE user_commission_plans (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    commission_plan_id UUID REFERENCES commission_plans(id),
    assigned_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    assigned_by UUID REFERENCES users(id),
    is_active BOOLEAN DEFAULT true
);

-- ===============================================
-- PRODUCTS & SALES
-- ===============================================

-- Products (what gets sold to generate commissions)
CREATE TABLE products (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    price DECIMAL(10,2) NOT NULL,
    cost DECIMAL(10,2) DEFAULT 0.00,
    sku VARCHAR(100) UNIQUE,
    category VARCHAR(100),
    is_digital BOOLEAN DEFAULT false,
    is_recurring BOOLEAN DEFAULT false,
    recurring_interval VARCHAR(20), -- 'monthly', 'yearly'
    is_active BOOLEAN DEFAULT true,
    commission_eligible BOOLEAN DEFAULT true,
    stock_quantity INTEGER DEFAULT 0,
    image_url TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Sales/Purchases
CREATE TABLE sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    buyer_id UUID REFERENCES users(id),
    product_id UUID REFERENCES products(id),
    quantity INTEGER DEFAULT 1,
    unit_price DECIMAL(10,2) NOT NULL,
    total_amount DECIMAL(10,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    tax_amount DECIMAL(10,2) DEFAULT 0.00,
    final_amount DECIMAL(10,2) NOT NULL,
    payment_status VARCHAR(20) DEFAULT 'pending' CHECK (payment_status IN ('pending', 'completed', 'failed', 'refunded')),
    payment_method VARCHAR(50),
    payment_transaction_id VARCHAR(255),
    stripe_payment_intent_id VARCHAR(255),
    refund_amount DECIMAL(10,2) DEFAULT 0.00,
    refund_date TIMESTAMP,
    order_notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- COMMISSION TRACKING
-- ===============================================

-- Commission calculations and records
CREATE TABLE commissions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE, -- Who earned the commission
    sale_id UUID REFERENCES sales(id),
    referral_id UUID REFERENCES referrals(id),
    commission_plan_id UUID REFERENCES commission_plans(id),
    
    commission_type VARCHAR(30) DEFAULT 'referral' CHECK (commission_type IN ('referral', 'signup_bonus', 'first_purchase_bonus', 'volume_bonus', 'rank_bonus')),
    level INTEGER DEFAULT 1, -- Which level in the MLM tree
    rate DECIMAL(5,2), -- Percentage rate used
    base_amount DECIMAL(10,2), -- Amount commission was calculated on
    commission_amount DECIMAL(10,2) NOT NULL,
    
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'paid', 'cancelled')),
    approved_at TIMESTAMP,
    approved_by UUID REFERENCES users(id),
    paid_at TIMESTAMP,
    payment_reference VARCHAR(255),
    
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- RANKS & ACHIEVEMENTS
-- ===============================================

-- Rank system
CREATE TABLE ranks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name VARCHAR(100) NOT NULL,
    description TEXT,
    requirements JSONB, -- Flexible requirements (sales volume, team size, etc.)
    benefits JSONB, -- Benefits for reaching this rank
    rank_order INTEGER UNIQUE, -- 1 = lowest rank, higher numbers = higher ranks
    icon_url TEXT,
    color_code VARCHAR(7), -- Hex color
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- User ranks (current and historical)
CREATE TABLE user_ranks (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    rank_id UUID REFERENCES ranks(id),
    achieved_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    is_current BOOLEAN DEFAULT true,
    qualified_period VARCHAR(20), -- 'monthly', 'quarterly', 'lifetime'
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- PAYMENTS & PAYOUTS
-- ===============================================

-- Payout requests and records
CREATE TABLE payouts (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    amount DECIMAL(10,2) NOT NULL,
    currency VARCHAR(10) DEFAULT 'USD',
    payment_method VARCHAR(30),
    payment_details JSONB, -- Bank details, PayPal email, etc.
    status VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending', 'processing', 'completed', 'failed', 'cancelled')),
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    processed_at TIMESTAMP,
    completed_at TIMESTAMP,
    failure_reason TEXT,
    transaction_id VARCHAR(255),
    notes TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- ANALYTICS & REPORTING
-- ===============================================

-- User statistics (denormalized for performance)
CREATE TABLE user_statistics (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    
    -- Referral stats
    total_direct_referrals INTEGER DEFAULT 0,
    total_indirect_referrals INTEGER DEFAULT 0,
    total_team_size INTEGER DEFAULT 0,
    active_referrals_last_30_days INTEGER DEFAULT 0,
    
    -- Commission stats
    total_commissions_earned DECIMAL(12,2) DEFAULT 0.00,
    commissions_this_month DECIMAL(12,2) DEFAULT 0.00,
    commissions_last_month DECIMAL(12,2) DEFAULT 0.00,
    total_commissions_paid DECIMAL(12,2) DEFAULT 0.00,
    pending_commission_balance DECIMAL(12,2) DEFAULT 0.00,
    
    -- Sales stats
    total_personal_sales DECIMAL(12,2) DEFAULT 0.00,
    personal_sales_this_month DECIMAL(12,2) DEFAULT 0.00,
    total_team_sales DECIMAL(12,2) DEFAULT 0.00,
    team_sales_this_month DECIMAL(12,2) DEFAULT 0.00,
    
    last_calculated TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- SYSTEM EVENTS & LOGS
-- ===============================================

-- Activity logs for auditing
CREATE TABLE activity_logs (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id),
    action VARCHAR(100) NOT NULL,
    resource_type VARCHAR(50), -- 'user', 'commission', 'sale', 'payout'
    resource_id UUID,
    details JSONB,
    ip_address INET,
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- System notifications
CREATE TABLE notifications (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID REFERENCES users(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL,
    message TEXT NOT NULL,
    type VARCHAR(30) DEFAULT 'info' CHECK (type IN ('info', 'success', 'warning', 'error', 'commission', 'payout', 'rank')),
    is_read BOOLEAN DEFAULT false,
    action_url TEXT,
    expires_at TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ===============================================
-- INDEXES FOR PERFORMANCE
-- ===============================================

-- User indexes
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_username ON users(username);
CREATE INDEX idx_users_status ON users(status);
CREATE INDEX idx_users_created_at ON users(created_at);

-- Referral indexes
CREATE INDEX idx_referrals_referrer_id ON referrals(referrer_id);
CREATE INDEX idx_referrals_referred_id ON referrals(referred_id);
CREATE INDEX idx_referrals_level ON referrals(level);
CREATE INDEX idx_referrals_status ON referrals(status);
CREATE INDEX idx_referrals_created_at ON referrals(created_at);

-- Commission indexes
CREATE INDEX idx_commissions_user_id ON commissions(user_id);
CREATE INDEX idx_commissions_sale_id ON commissions(sale_id);
CREATE INDEX idx_commissions_status ON commissions(status);
CREATE INDEX idx_commissions_created_at ON commissions(created_at);
CREATE INDEX idx_commissions_level ON commissions(level);

-- Sales indexes
CREATE INDEX idx_sales_buyer_id ON sales(buyer_id);
CREATE INDEX idx_sales_product_id ON sales(product_id);
CREATE INDEX idx_sales_payment_status ON sales(payment_status);
CREATE INDEX idx_sales_created_at ON sales(created_at);

-- Activity logs index
CREATE INDEX idx_activity_logs_user_id ON activity_logs(user_id);
CREATE INDEX idx_activity_logs_created_at ON activity_logs(created_at);
CREATE INDEX idx_activity_logs_action ON activity_logs(action);

-- ===============================================
-- SAMPLE DATA
-- ===============================================

-- Insert default commission plan
INSERT INTO commission_plans (name, description, plan_type, direct_referral_rate, level_2_rate, level_3_rate, level_4_rate, level_5_rate, max_levels, signup_bonus, first_purchase_bonus)
VALUES ('Standard MLM Plan', 'Default commission plan with 5 levels', 'percentage', 15.00, 8.00, 5.00, 3.00, 2.00, 5, 25.00, 50.00);

-- Insert sample ranks
INSERT INTO ranks (name, description, rank_order, requirements, benefits, color_code) VALUES
('Bronze', 'Entry level rank', 1, '{"min_referrals": 0, "min_sales": 0}', '{"commission_bonus": 0}', '#CD7F32'),
('Silver', 'Second tier rank', 2, '{"min_referrals": 5, "min_sales": 1000}', '{"commission_bonus": 5}', '#C0C0C0'),
('Gold', 'Third tier rank', 3, '{"min_referrals": 15, "min_sales": 5000}', '{"commission_bonus": 10}', '#FFD700'),
('Platinum', 'Fourth tier rank', 4, '{"min_referrals": 30, "min_sales": 15000}', '{"commission_bonus": 15}', '#E5E4E2'),
('Diamond', 'Top tier rank', 5, '{"min_referrals": 50, "min_sales": 50000}', '{"commission_bonus": 25}', '#B9F2FF');

-- Insert sample products
INSERT INTO products (name, description, price, cost, sku, category, is_digital, commission_eligible) VALUES
('Premium Course Bundle', 'Complete digital marketing course', 297.00, 50.00, 'COURSE-001', 'Education', true, true),
('Monthly Subscription', 'Access to premium tools and resources', 97.00, 20.00, 'SUB-001', 'Subscription', true, true),
('Coaching Session', '1-on-1 coaching session with expert', 197.00, 75.00, 'COACH-001', 'Services', true, true),
('Physical Product', 'Sample physical product', 49.99, 25.00, 'PHYS-001', 'Physical', false, true);

-- ===============================================
-- FUNCTIONS FOR CALCULATIONS
-- ===============================================

-- Function to calculate referral tree depth
CREATE OR REPLACE FUNCTION get_user_referral_depth(user_uuid UUID)
RETURNS INTEGER AS $$
DECLARE
    max_depth INTEGER := 0;
    current_depth INTEGER := 0;
BEGIN
    WITH RECURSIVE referral_tree AS (
        -- Base case: direct referrals
        SELECT referred_id, 1 as depth
        FROM referrals 
        WHERE referrer_id = user_uuid AND status = 'active'
        
        UNION ALL
        
        -- Recursive case: indirect referrals
        SELECT r.referred_id, rt.depth + 1
        FROM referrals r
        INNER JOIN referral_tree rt ON r.referrer_id = rt.referred_id
        WHERE r.status = 'active' AND rt.depth < 10 -- Limit recursion depth
    )
    SELECT COALESCE(MAX(depth), 0) INTO max_depth FROM referral_tree;
    
    RETURN max_depth;
END;
$$ LANGUAGE plpgsql;

-- Function to get all downline users
CREATE OR REPLACE FUNCTION get_user_downline(user_uuid UUID, max_depth INTEGER DEFAULT 10)
RETURNS TABLE(user_id UUID, depth INTEGER) AS $$
BEGIN
    RETURN QUERY
    WITH RECURSIVE referral_tree AS (
        -- Base case: direct referrals
        SELECT r.referred_id as user_id, 1 as depth
        FROM referrals r
        WHERE r.referrer_id = user_uuid AND r.status = 'active'
        
        UNION ALL
        
        -- Recursive case: indirect referrals
        SELECT r.referred_id as user_id, rt.depth + 1
        FROM referrals r
        INNER JOIN referral_tree rt ON r.referrer_id = rt.user_id
        WHERE r.status = 'active' AND rt.depth < max_depth
    )
    SELECT rt.user_id, rt.depth FROM referral_tree ORDER BY depth, user_id;
END;
$$ LANGUAGE plpgsql;

-- ===============================================
-- TRIGGERS FOR AUTOMATIC UPDATES
-- ===============================================

-- Update timestamps trigger function
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Apply update triggers to relevant tables
CREATE TRIGGER update_users_updated_at BEFORE UPDATE ON users FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_settings_updated_at BEFORE UPDATE ON user_settings FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_referral_codes_updated_at BEFORE UPDATE ON referral_codes FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_referrals_updated_at BEFORE UPDATE ON referrals FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_commission_plans_updated_at BEFORE UPDATE ON commission_plans FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_products_updated_at BEFORE UPDATE ON products FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_sales_updated_at BEFORE UPDATE ON sales FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_commissions_updated_at BEFORE UPDATE ON commissions FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_payouts_updated_at BEFORE UPDATE ON payouts FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
CREATE TRIGGER update_user_statistics_updated_at BEFORE UPDATE ON user_statistics FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

COMMIT;
