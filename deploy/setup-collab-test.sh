#!/bin/bash
# Auto-Collaboration Test Setup Script
# Creates test data for manual frontend testing
# 
# Usage: ./setup-collab-test.sh [base_url]
#
# This script:
# 1. Creates a test user (or uses existing)
# 2. Creates a shared workspace
# 3. Creates a team and adds the test user
# 4. Creates a non-private collection and assigns the team
# 5. Creates a scene in that collection
# 6. Outputs all credentials and URLs for manual testing
#
# DOES NOT clean up - data remains for testing!

BASE_URL="${1:-https://10.100.0.10}"
COOKIES_FILE="/tmp/astradraw-setup-cookies.txt"
SUPERADMIN_COOKIES="/tmp/astradraw-setup-superadmin.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Fixed test user credentials (easy to remember)
TEST_USER_EMAIL="testuser@example.com"
TEST_USER_PASSWORD="testpass123"
TEST_USER_NAME="Test User"

# Super admin credentials (from env.example defaults)
SUPERADMIN_EMAIL="${SUPERADMIN_EMAIL:-admin@localhost}"
SUPERADMIN_PASSWORD="${SUPERADMIN_PASSWORD:-admin}"

# API call helper
api_call() {
    local method="$1"
    local endpoint="$2"
    local data="$3"
    local cookies="${4:-$COOKIES_FILE}"
    
    if [ -n "$data" ]; then
        curl -s -X "$method" "${BASE_URL}${endpoint}" \
            -H "Content-Type: application/json" \
            -d "$data" \
            -k -c "$cookies" -b "$cookies"
    else
        curl -s -X "$method" "${BASE_URL}${endpoint}" \
            -k -c "$cookies" -b "$cookies"
    fi
}

# Clean up old cookies
rm -f "$COOKIES_FILE" "$SUPERADMIN_COOKIES"

echo ""
echo -e "${BOLD}========================================"
echo "  Auto-Collaboration Test Setup"
echo "  Base URL: $BASE_URL"
echo "========================================${NC}"
echo ""

# ============================================================================
# STEP 1: Create or login test user
# ============================================================================

echo -e "${YELLOW}Step 1: Setting up test user...${NC}"

# Try to register the test user
REGISTER_RESPONSE=$(api_call POST "/api/v2/auth/register" "{\"email\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\",\"name\":\"$TEST_USER_NAME\"}")

if echo "$REGISTER_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Created new test user"
    TEST_USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
elif echo "$REGISTER_RESPONSE" | grep -q 'already exists\|duplicate'; then
    echo -e "${CYAN}ℹ${NC} Test user already exists, logging in..."
else
    echo -e "${CYAN}ℹ${NC} Registration response: $REGISTER_RESPONSE"
fi

# Login as test user
LOGIN_RESPONSE=$(api_call POST "/api/v2/auth/login/local" "{\"username\":\"$TEST_USER_EMAIL\",\"password\":\"$TEST_USER_PASSWORD\"}")

if echo "$LOGIN_RESPONSE" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Test user logged in"
    # Get user ID from profile
    PROFILE_RESPONSE=$(api_call GET "/api/v2/users/me")
    TEST_USER_ID=$(echo "$PROFILE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
else
    echo -e "${RED}✗${NC} Failed to login test user"
    echo "  Response: $LOGIN_RESPONSE"
    exit 1
fi

# ============================================================================
# STEP 2: Login as super admin
# ============================================================================

echo -e "${YELLOW}Step 2: Logging in as super admin...${NC}"

SUPERADMIN_LOGIN=$(api_call POST "/api/v2/auth/login/local" "{\"username\":\"$SUPERADMIN_EMAIL\",\"password\":\"$SUPERADMIN_PASSWORD\"}" "$SUPERADMIN_COOKIES")

if echo "$SUPERADMIN_LOGIN" | grep -q '"success":true'; then
    echo -e "${GREEN}✓${NC} Super admin logged in"
else
    echo -e "${RED}✗${NC} Failed to login super admin"
    echo "  Response: $SUPERADMIN_LOGIN"
    echo ""
    echo "  Make sure SUPERADMIN_EMAILS includes $SUPERADMIN_EMAIL in your .env"
    exit 1
fi

# ============================================================================
# STEP 3: Create shared workspace
# ============================================================================

echo -e "${YELLOW}Step 3: Creating shared workspace...${NC}"

WORKSPACE_NAME="Collaboration Test"
WORKSPACE_SLUG="collab-test"

# Check if workspace already exists
EXISTING_WS=$(api_call GET "/api/v2/workspaces" "" "$SUPERADMIN_COOKIES")
if echo "$EXISTING_WS" | grep -q "\"slug\":\"$WORKSPACE_SLUG\""; then
    echo -e "${CYAN}ℹ${NC} Workspace '$WORKSPACE_SLUG' already exists"
    WORKSPACE_ID=$(echo "$EXISTING_WS" | grep -o "\"id\":\"[^\"]*\",\"name\":\"[^\"]*\",\"slug\":\"$WORKSPACE_SLUG\"" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)
    if [ -z "$WORKSPACE_ID" ]; then
        # Try different parsing
        WORKSPACE_ID=$(echo "$EXISTING_WS" | sed 's/},{/}\n{/g' | grep "\"slug\":\"$WORKSPACE_SLUG\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    fi
else
    CREATE_WS_RESPONSE=$(api_call POST "/api/v2/workspaces" "{\"name\":\"$WORKSPACE_NAME\",\"slug\":\"$WORKSPACE_SLUG\",\"type\":\"SHARED\"}" "$SUPERADMIN_COOKIES")
    
    if echo "$CREATE_WS_RESPONSE" | grep -q '"id":'; then
        echo -e "${GREEN}✓${NC} Created shared workspace"
        WORKSPACE_ID=$(echo "$CREATE_WS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}✗${NC} Failed to create workspace"
        echo "  Response: $CREATE_WS_RESPONSE"
        exit 1
    fi
fi

echo "  Workspace ID: $WORKSPACE_ID"

# ============================================================================
# STEP 4: Invite test user to workspace
# ============================================================================

echo -e "${YELLOW}Step 4: Inviting test user to workspace...${NC}"

INVITE_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/members/invite" "{\"email\":\"$TEST_USER_EMAIL\",\"role\":\"MEMBER\"}" "$SUPERADMIN_COOKIES")

if echo "$INVITE_RESPONSE" | grep -q '"success":true\|"id":'; then
    echo -e "${GREEN}✓${NC} Test user invited to workspace"
elif echo "$INVITE_RESPONSE" | grep -q 'already'; then
    echo -e "${CYAN}ℹ${NC} Test user already a member"
else
    echo -e "${RED}✗${NC} Failed to invite test user"
    echo "  Response: $INVITE_RESPONSE"
fi

# ============================================================================
# STEP 5: Create team
# ============================================================================

echo -e "${YELLOW}Step 5: Creating team...${NC}"

TEAM_NAME="Test Team"

# List existing teams
EXISTING_TEAMS=$(api_call GET "/api/v2/workspaces/$WORKSPACE_ID/teams" "" "$SUPERADMIN_COOKIES")
if echo "$EXISTING_TEAMS" | grep -q "\"name\":\"$TEAM_NAME\""; then
    echo -e "${CYAN}ℹ${NC} Team '$TEAM_NAME' already exists"
    TEAM_ID=$(echo "$EXISTING_TEAMS" | sed 's/},{/}\n{/g' | grep "\"name\":\"$TEAM_NAME\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
else
    TEAM_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/teams" "{\"name\":\"$TEAM_NAME\",\"color\":\"#3498db\",\"memberIds\":[\"$TEST_USER_ID\"]}" "$SUPERADMIN_COOKIES")
    
    if echo "$TEAM_RESPONSE" | grep -q '"id":'; then
        echo -e "${GREEN}✓${NC} Created team"
        TEAM_ID=$(echo "$TEAM_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}✗${NC} Failed to create team"
        echo "  Response: $TEAM_RESPONSE"
    fi
fi

echo "  Team ID: $TEAM_ID"

# ============================================================================
# STEP 6: Create collection (non-private)
# ============================================================================

echo -e "${YELLOW}Step 6: Creating shared collection...${NC}"

COLLECTION_NAME="Shared Drawings"

# List existing collections
EXISTING_COLS=$(api_call GET "/api/v2/workspaces/$WORKSPACE_ID/collections" "" "$SUPERADMIN_COOKIES")
if echo "$EXISTING_COLS" | grep -q "\"name\":\"$COLLECTION_NAME\""; then
    echo -e "${CYAN}ℹ${NC} Collection '$COLLECTION_NAME' already exists"
    COLLECTION_ID=$(echo "$EXISTING_COLS" | sed 's/},{/}\n{/g' | grep "\"name\":\"$COLLECTION_NAME\"" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
else
    COLLECTION_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/collections" "{\"name\":\"$COLLECTION_NAME\",\"icon\":\"📁\",\"isPrivate\":false}" "$SUPERADMIN_COOKIES")
    
    if echo "$COLLECTION_RESPONSE" | grep -q '"id":'; then
        echo -e "${GREEN}✓${NC} Created shared collection"
        COLLECTION_ID=$(echo "$COLLECTION_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    else
        echo -e "${RED}✗${NC} Failed to create collection"
        echo "  Response: $COLLECTION_RESPONSE"
    fi
fi

echo "  Collection ID: $COLLECTION_ID"

# ============================================================================
# STEP 7: Assign team to collection with EDIT access
# ============================================================================

echo -e "${YELLOW}Step 7: Assigning team to collection...${NC}"

if [ -n "$TEAM_ID" ] && [ -n "$COLLECTION_ID" ]; then
    ACCESS_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/collections/$COLLECTION_ID/teams" "{\"teamId\":\"$TEAM_ID\",\"accessLevel\":\"EDIT\"}" "$SUPERADMIN_COOKIES")
    
    if echo "$ACCESS_RESPONSE" | grep -q '"success":true\|EDIT'; then
        echo -e "${GREEN}✓${NC} Team assigned to collection with EDIT access"
    elif echo "$ACCESS_RESPONSE" | grep -q 'already'; then
        echo -e "${CYAN}ℹ${NC} Team already has access"
    else
        echo -e "${YELLOW}⚠${NC} Could not assign team (may already exist)"
    fi
fi

# ============================================================================
# STEP 8: Create scene in collection
# ============================================================================

echo -e "${YELLOW}Step 8: Creating test scene...${NC}"

SCENE_TITLE="Auto-Collab Test Scene"

SCENE_RESPONSE=$(api_call POST "/api/v2/workspace/scenes" "{\"title\":\"$SCENE_TITLE\",\"collectionId\":\"$COLLECTION_ID\"}" "$SUPERADMIN_COOKIES")

if echo "$SCENE_RESPONSE" | grep -q '"id":'; then
    echo -e "${GREEN}✓${NC} Created test scene"
    SCENE_ID=$(echo "$SCENE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    ROOM_ID=$(echo "$SCENE_RESPONSE" | grep -o '"roomId":"[^"]*"' | cut -d'"' -f4)
    
    if [ -n "$ROOM_ID" ] && [ "$ROOM_ID" != "null" ]; then
        echo -e "${GREEN}✓${NC} Scene has auto-generated roomId: $ROOM_ID"
    else
        echo -e "${RED}✗${NC} Scene does NOT have roomId - auto-collaboration not working!"
    fi
else
    echo -e "${RED}✗${NC} Failed to create scene"
    echo "  Response: $SCENE_RESPONSE"
fi

# ============================================================================
# OUTPUT SUMMARY
# ============================================================================

# Build the scene URL
SCENE_URL="${BASE_URL}/workspace/${WORKSPACE_SLUG}/scene/${SCENE_ID}"

echo ""
echo -e "${BOLD}========================================"
echo "  Setup Complete!"
echo "========================================${NC}"
echo ""
echo -e "${BOLD}${CYAN}User 1 (Super Admin):${NC}"
echo "  Email:    $SUPERADMIN_EMAIL"
echo "  Password: $SUPERADMIN_PASSWORD"
echo ""
echo -e "${BOLD}${CYAN}User 2 (Test User):${NC}"
echo "  Email:    $TEST_USER_EMAIL"
echo "  Password: $TEST_USER_PASSWORD"
echo ""
echo -e "${BOLD}${CYAN}Workspace:${NC}"
echo "  Name: $WORKSPACE_NAME"
echo "  Slug: $WORKSPACE_SLUG"
echo "  URL:  ${BASE_URL}/workspace/${WORKSPACE_SLUG}/dashboard"
echo ""
echo -e "${BOLD}${CYAN}Collection:${NC}"
echo "  Name: $COLLECTION_NAME"
echo "  URL:  ${BASE_URL}/workspace/${WORKSPACE_SLUG}/collection/${COLLECTION_ID}"
echo ""
echo -e "${BOLD}${CYAN}Scene (Auto-Collaboration Enabled):${NC}"
echo "  Title:   $SCENE_TITLE"
echo "  Room ID: $ROOM_ID"
echo "  URL:     $SCENE_URL"
echo ""
echo -e "${BOLD}${YELLOW}========================================"
echo "  How to Test"
echo "========================================${NC}"
echo ""
echo "1. Open Browser 1 (e.g., Chrome):"
echo "   - Go to: ${BASE_URL}"
echo "   - Login as: $SUPERADMIN_EMAIL / $SUPERADMIN_PASSWORD"
echo "   - Navigate to: $SCENE_URL"
echo ""
echo "2. Open Browser 2 (e.g., Firefox or Incognito):"
echo "   - Go to: ${BASE_URL}"
echo "   - Login as: $TEST_USER_EMAIL / $TEST_USER_PASSWORD"
echo "   - Navigate to: $SCENE_URL"
echo ""
echo "3. Both users should automatically see each other's cursors!"
echo "   - No 'Share' button needed"
echo "   - Try drawing - changes should sync in real-time"
echo ""
echo -e "${BOLD}${GREEN}Happy testing! 🎉${NC}"
echo ""

# Clean up cookie files
rm -f "$COOKIES_FILE" "$SUPERADMIN_COOKIES"

exit 0

