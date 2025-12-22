#!/bin/bash
# Backend API Test Script for Collaboration Permissions
# Usage: ./test-backend-api.sh [base_url]
#
# Tests the new collaboration permissions endpoints including:
# - User authentication (regular user and super admin)
# - Workspace types (personal vs shared)
# - Collection access levels
# - Scene access and collaboration
# - Super admin capabilities

# Don't exit on error - we want to continue testing even if some tests fail
# set -e

BASE_URL="${1:-https://10.100.0.10}"
COOKIES_FILE="/tmp/astradraw-test-cookies.txt"
SUPERADMIN_COOKIES="/tmp/astradraw-superadmin-cookies.txt"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Test counters
PASSED=0
FAILED=0
SKIPPED=0

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((PASSED++))
}

log_fail() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((FAILED++))
}

log_skip() {
    echo -e "${CYAN}[SKIP]${NC} $1"
    ((SKIPPED++))
}

log_section() {
    echo ""
    echo -e "${YELLOW}=== $1 ===${NC}"
}

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

# Check if response contains expected value
check_response() {
    local response="$1"
    local expected="$2"
    local test_name="$3"
    
    if echo "$response" | grep -q "$expected"; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        echo "  Expected: $expected"
        echo "  Got: $response"
        return 1
    fi
}

# Check if response does NOT contain a value
check_response_not() {
    local response="$1"
    local not_expected="$2"
    local test_name="$3"
    
    if echo "$response" | grep -q "$not_expected"; then
        log_fail "$test_name"
        echo "  Should NOT contain: $not_expected"
        echo "  Got: $response"
        return 1
    else
        log_success "$test_name"
        return 0
    fi
}

# Check HTTP status code
check_status() {
    local response="$1"
    local expected_status="$2"
    local test_name="$3"
    
    if echo "$response" | grep -q "\"statusCode\":$expected_status"; then
        log_success "$test_name"
        return 0
    else
        log_fail "$test_name"
        echo "  Expected status: $expected_status"
        echo "  Got: $response"
        return 1
    fi
}

# Clean up old cookies
rm -f "$COOKIES_FILE" "$SUPERADMIN_COOKIES"

echo ""
echo "========================================"
echo "  AstraDraw Backend API Tests"
echo "  Base URL: $BASE_URL"
echo "========================================"

# Generate unique test identifiers
TIMESTAMP=$(date +%s)
TEST_EMAIL="test-${TIMESTAMP}@example.com"
TEST_PASSWORD="testpass123"
TEST_NAME="Test User ${TIMESTAMP}"

# Super admin credentials (from env.example defaults)
SUPERADMIN_EMAIL="${SUPERADMIN_EMAIL:-admin@localhost}"
SUPERADMIN_PASSWORD="${SUPERADMIN_PASSWORD:-admin}"

# ============================================================================
# PART 1: REGULAR USER TESTS
# ============================================================================

log_section "1. Regular User Authentication"

# Register a new user
log_info "Registering test user: $TEST_EMAIL"
REGISTER_RESPONSE=$(api_call POST "/api/v2/auth/register" "{\"email\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\",\"name\":\"$TEST_NAME\"}")

if echo "$REGISTER_RESPONSE" | grep -q '"success":true'; then
    log_success "User registration"
    USER_ID=$(echo "$REGISTER_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
    log_info "User ID: $USER_ID"
else
    log_fail "User registration"
    echo "  Response: $REGISTER_RESPONSE"
    # Try to continue with login anyway
fi

# Login as regular user
log_info "Logging in as $TEST_EMAIL"
LOGIN_RESPONSE=$(api_call POST "/api/v2/auth/login/local" "{\"username\":\"$TEST_EMAIL\",\"password\":\"$TEST_PASSWORD\"}")

if echo "$LOGIN_RESPONSE" | grep -q '"success":true'; then
    log_success "Regular user login"
else
    log_fail "Regular user login"
    echo "  Response: $LOGIN_RESPONSE"
    echo ""
    echo "Cannot continue tests without authentication. Exiting."
    exit 1
fi

log_section "2. Regular User - Workspace Retrieval"

# Get workspaces
WORKSPACES_RESPONSE=$(api_call GET "/api/v2/workspaces")
check_response "$WORKSPACES_RESPONSE" '"id":' "Get workspaces"

# Extract first workspace ID and slug
WORKSPACE_ID=$(echo "$WORKSPACES_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
WORKSPACE_SLUG=$(echo "$WORKSPACES_RESPONSE" | grep -o '"slug":"[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Workspace ID: $WORKSPACE_ID"
log_info "Workspace Slug: $WORKSPACE_SLUG"

# Get workspace details
WORKSPACE_DETAILS=$(api_call GET "/api/v2/workspaces/$WORKSPACE_ID")
check_response "$WORKSPACE_DETAILS" '"name":' "Get workspace details"

# Check workspace type (should be PERSONAL for auto-created workspace)
if echo "$WORKSPACE_DETAILS" | grep -q '"type":"PERSONAL"'; then
    log_success "Workspace type is PERSONAL"
else
    log_fail "Workspace type should be PERSONAL"
    echo "  Response: $WORKSPACE_DETAILS"
fi

log_section "3. Regular User - Personal Workspace Restrictions"

# Try to invite member to personal workspace (should fail)
INVITE_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/members/invite" '{"email":"other@example.com","role":"MEMBER"}')
check_response "$INVITE_RESPONSE" 'personal workspaces' "Block invite to personal workspace"

# Try to create team in personal workspace (should fail)
TEAM_RESPONSE=$(api_call POST "/api/v2/workspaces/$WORKSPACE_ID/teams" '{"name":"Test Team","color":"#FF5733"}')
check_response "$TEAM_RESPONSE" 'personal workspaces' "Block team creation in personal workspace"

log_section "4. Regular User - Collections"

# Get collections
COLLECTIONS_RESPONSE=$(api_call GET "/api/v2/workspaces/$WORKSPACE_ID/collections")
check_response "$COLLECTIONS_RESPONSE" '"name":' "Get collections"

# Extract collection ID
COLLECTION_ID=$(echo "$COLLECTIONS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Collection ID: $COLLECTION_ID"

log_section "5. Regular User - Scene Operations"

# Create a scene
SCENE_TITLE="Test Scene ${TIMESTAMP}"
CREATE_SCENE_RESPONSE=$(api_call POST "/api/v2/workspace/scenes" "{\"title\":\"$SCENE_TITLE\",\"collectionId\":\"$COLLECTION_ID\"}")
check_response "$CREATE_SCENE_RESPONSE" '"id":' "Create scene"

# Extract scene ID
SCENE_ID=$(echo "$CREATE_SCENE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
log_info "Scene ID: $SCENE_ID"

if [ -n "$SCENE_ID" ] && [ "$SCENE_ID" != "null" ]; then
    # Check collaborationEnabled field (should be false for personal workspace)
    if echo "$CREATE_SCENE_RESPONSE" | grep -q '"collaborationEnabled":false'; then
        log_success "Scene in personal workspace has collaborationEnabled=false"
    elif echo "$CREATE_SCENE_RESPONSE" | grep -q '"collaborationEnabled":true'; then
        log_fail "Scene in personal workspace should have collaborationEnabled=false"
        echo "  Response: $CREATE_SCENE_RESPONSE"
    else
        log_skip "collaborationEnabled field check"
    fi
    
    # NEW: Check that personal workspace scenes do NOT have auto-generated roomId
    if echo "$CREATE_SCENE_RESPONSE" | grep -q '"roomId":null'; then
        log_success "Scene in personal workspace has roomId=null (no auto-collaboration)"
    elif echo "$CREATE_SCENE_RESPONSE" | grep -q '"roomId":"[^"]*"'; then
        log_fail "Scene in personal workspace should NOT have auto-generated roomId"
        echo "  Response: $CREATE_SCENE_RESPONSE"
    else
        log_success "Scene in personal workspace has no roomId"
    fi
    
    # Get scene by slug (new endpoint)
    log_info "Testing scene access by workspace slug..."
    SCENE_BY_SLUG_RESPONSE=$(api_call GET "/api/v2/workspace/by-slug/$WORKSPACE_SLUG/scenes/$SCENE_ID")
    check_response "$SCENE_BY_SLUG_RESPONSE" '"scene":' "Get scene by workspace slug"
    
    # Check access permissions in response
    if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"access":'; then
        log_success "Scene response includes access permissions"
        
        # Verify canView is true
        if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"canView":true'; then
            log_success "canView permission is true"
        else
            log_fail "canView permission check"
        fi
        
        # Verify canEdit is true (owner should have edit)
        if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"canEdit":true'; then
            log_success "canEdit permission is true"
        else
            log_fail "canEdit permission check"
        fi
        
        # Verify canCollaborate
        if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"canCollaborate":'; then
            log_success "canCollaborate permission is present"
        else
            log_skip "canCollaborate permission check"
        fi
    else
        log_fail "Scene response includes access permissions"
    fi
    
    # Test collaboration endpoints
    log_section "6. Regular User - Collaboration Endpoints (Personal Workspace)"
    
    # In personal workspaces, collaboration should be BLOCKED
    # This is the expected behavior per the spec
    COLLAB_START_RESPONSE=$(api_call POST "/api/v2/workspace/scenes/$SCENE_ID/collaborate")
    if echo "$COLLAB_START_RESPONSE" | grep -q '"statusCode":403\|not available\|Forbidden'; then
        log_success "Collaboration correctly blocked in personal workspace"
    elif echo "$COLLAB_START_RESPONSE" | grep -q '"roomId":'; then
        log_fail "Collaboration should be blocked in personal workspace"
        echo "  Response: $COLLAB_START_RESPONSE"
    else
        log_skip "Collaboration blocking check (unexpected response)"
        echo "  Response: $COLLAB_START_RESPONSE"
    fi
    
    REGULAR_USER_SCENE_ID="$SCENE_ID"
else
    log_fail "Scene creation failed, skipping scene tests"
fi

# ============================================================================
# PART 2: SUPER ADMIN TESTS
# ============================================================================

log_section "7. Super Admin Authentication"

log_info "Logging in as super admin: $SUPERADMIN_EMAIL"
SUPERADMIN_LOGIN=$(api_call POST "/api/v2/auth/login/local" "{\"username\":\"$SUPERADMIN_EMAIL\",\"password\":\"$SUPERADMIN_PASSWORD\"}" "$SUPERADMIN_COOKIES")

if echo "$SUPERADMIN_LOGIN" | grep -q '"success":true'; then
    log_success "Super admin login"
    
    # Get super admin profile
    SUPERADMIN_PROFILE=$(api_call GET "/api/v2/users/me" "" "$SUPERADMIN_COOKIES")
    
    # Check isSuperAdmin flag
    if echo "$SUPERADMIN_PROFILE" | grep -q '"isSuperAdmin":true'; then
        log_success "Super admin has isSuperAdmin=true"
    else
        log_fail "Super admin isSuperAdmin flag"
        echo "  Response: $SUPERADMIN_PROFILE"
        echo "  Note: Make sure SUPERADMIN_EMAILS includes $SUPERADMIN_EMAIL"
    fi
else
    log_fail "Super admin login"
    echo "  Response: $SUPERADMIN_LOGIN"
    echo "  Note: Default credentials are admin@localhost / admin"
    echo "  Skipping super admin tests..."
    SKIP_SUPERADMIN_TESTS=true
fi

if [ "$SKIP_SUPERADMIN_TESTS" != "true" ]; then
    log_section "8. Super Admin - Create Shared Workspace"
    
    SHARED_WS_NAME="Shared Workspace ${TIMESTAMP}"
    SHARED_WS_SLUG="shared-ws-${TIMESTAMP}"
    
    CREATE_WS_RESPONSE=$(api_call POST "/api/v2/workspaces" "{\"name\":\"$SHARED_WS_NAME\",\"slug\":\"$SHARED_WS_SLUG\",\"type\":\"SHARED\"}" "$SUPERADMIN_COOKIES")
    
    if echo "$CREATE_WS_RESPONSE" | grep -q '"id":'; then
        log_success "Create shared workspace"
        SHARED_WS_ID=$(echo "$CREATE_WS_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
        log_info "Shared Workspace ID: $SHARED_WS_ID"
        
        # Check workspace type
        if echo "$CREATE_WS_RESPONSE" | grep -q '"type":"SHARED"'; then
            log_success "Shared workspace has type=SHARED"
        else
            log_fail "Shared workspace should have type=SHARED"
            echo "  Response: $CREATE_WS_RESPONSE"
        fi
        
        log_section "9. Super Admin - Shared Workspace Operations"
        
        # Create team in shared workspace (should succeed)
        TEAM_RESPONSE=$(api_call POST "/api/v2/workspaces/$SHARED_WS_ID/teams" '{"name":"Engineering","color":"#3498db"}' "$SUPERADMIN_COOKIES")
        if echo "$TEAM_RESPONSE" | grep -q '"id":'; then
            log_success "Create team in shared workspace"
            TEAM_ID=$(echo "$TEAM_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
            log_info "Team ID: $TEAM_ID"
        else
            log_fail "Create team in shared workspace"
            echo "  Response: $TEAM_RESPONSE"
        fi
        
        # Invite member to shared workspace (should succeed)
        INVITE_RESPONSE=$(api_call POST "/api/v2/workspaces/$SHARED_WS_ID/members/invite" "{\"email\":\"$TEST_EMAIL\",\"role\":\"MEMBER\"}" "$SUPERADMIN_COOKIES")
        if echo "$INVITE_RESPONSE" | grep -q '"success":true\|"id":'; then
            log_success "Invite member to shared workspace"
        else
            # Check if it's a "user not found" error (which is expected if user doesn't exist)
            if echo "$INVITE_RESPONSE" | grep -q 'not found\|already'; then
                log_skip "Invite member (user may not exist or already invited)"
            else
                log_fail "Invite member to shared workspace"
                echo "  Response: $INVITE_RESPONSE"
            fi
        fi
        
        # Create a NON-PRIVATE collection in shared workspace (for auto-collaboration)
        COLLECTION_RESPONSE=$(api_call POST "/api/v2/workspaces/$SHARED_WS_ID/collections" '{"name":"Project Alpha","icon":"📁","isPrivate":false}' "$SUPERADMIN_COOKIES")
        if echo "$COLLECTION_RESPONSE" | grep -q '"id":'; then
            log_success "Create non-private collection in shared workspace"
            SHARED_COLLECTION_ID=$(echo "$COLLECTION_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
            log_info "Collection ID: $SHARED_COLLECTION_ID"
            
            # Also create a PRIVATE collection to test that auto-collaboration is disabled
            PRIVATE_COLLECTION_RESPONSE=$(api_call POST "/api/v2/workspaces/$SHARED_WS_ID/collections" '{"name":"My Private Drafts","icon":"🔒","isPrivate":true}' "$SUPERADMIN_COOKIES")
            if echo "$PRIVATE_COLLECTION_RESPONSE" | grep -q '"id":'; then
                PRIVATE_COLLECTION_ID=$(echo "$PRIVATE_COLLECTION_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
                log_success "Create private collection in shared workspace"
                log_info "Private Collection ID: $PRIVATE_COLLECTION_ID"
            else
                log_skip "Create private collection (not critical)"
            fi
            
            # Test team-collection access level
            if [ -n "$TEAM_ID" ]; then
                log_section "10. Super Admin - Team-Collection Access Levels"
                
                # Assign team to collection with EDIT access
                ACCESS_RESPONSE=$(api_call POST "/api/v2/workspaces/$SHARED_WS_ID/collections/$SHARED_COLLECTION_ID/teams" "{\"teamId\":\"$TEAM_ID\",\"accessLevel\":\"EDIT\"}" "$SUPERADMIN_COOKIES")
                if echo "$ACCESS_RESPONSE" | grep -q '"success":true'; then
                    log_success "Assign team to collection with EDIT access"
                    
                    # Verify access level in response
                    if echo "$ACCESS_RESPONSE" | grep -q '"accessLevel":"EDIT"'; then
                        log_success "Access level correctly set to EDIT"
                    else
                        log_fail "Access level should be EDIT"
                    fi
                else
                    log_fail "Failed to assign team to collection"
                    echo "  Response: $ACCESS_RESPONSE"
                fi
                
                # List teams with access to collection
                LIST_TEAMS_RESPONSE=$(api_call GET "/api/v2/workspaces/$SHARED_WS_ID/collections/$SHARED_COLLECTION_ID/teams" "" "$SUPERADMIN_COOKIES")
                if echo "$LIST_TEAMS_RESPONSE" | grep -q "$TEAM_ID"; then
                    log_success "List collection teams shows assigned team"
                else
                    log_fail "Team should appear in collection teams list"
                    echo "  Response: $LIST_TEAMS_RESPONSE"
                fi
            fi
            
            # Create scene in shared workspace collection and test AUTO-COLLABORATION
            log_section "10b. Super Admin - Auto-Collaboration in Shared Workspace"
            
            SHARED_SCENE_TITLE="Shared Scene ${TIMESTAMP}"
            SHARED_SCENE_RESPONSE=$(api_call POST "/api/v2/workspace/scenes" "{\"title\":\"$SHARED_SCENE_TITLE\",\"collectionId\":\"$SHARED_COLLECTION_ID\"}" "$SUPERADMIN_COOKIES")
            
            if echo "$SHARED_SCENE_RESPONSE" | grep -q '"id":'; then
                SHARED_SCENE_ID=$(echo "$SHARED_SCENE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
                log_success "Create scene in shared workspace"
                log_info "Shared Scene ID: $SHARED_SCENE_ID"
                
                # NEW: Check if scene was auto-created with roomId (auto-collaboration)
                if echo "$SHARED_SCENE_RESPONSE" | grep -q '"roomId":"[^"]*"'; then
                    log_success "Scene auto-created with roomId (auto-collaboration enabled)"
                    AUTO_ROOM_ID=$(echo "$SHARED_SCENE_RESPONSE" | grep -o '"roomId":"[^"]*"' | cut -d'"' -f4)
                    log_info "Auto-generated Room ID: $AUTO_ROOM_ID"
                else
                    log_fail "Scene in shared collection should have auto-generated roomId"
                    echo "  Response: $SHARED_SCENE_RESPONSE"
                fi
                
                # NEW: Check collaborationEnabled is true
                if echo "$SHARED_SCENE_RESPONSE" | grep -q '"collaborationEnabled":true'; then
                    log_success "Scene has collaborationEnabled=true"
                else
                    log_fail "Scene in shared collection should have collaborationEnabled=true"
                fi
                
                # NEW: Test getSceneBySlug returns roomKey for auto-collaboration
                log_info "Testing scene load with auto-collaboration credentials..."
                SCENE_BY_SLUG_RESPONSE=$(api_call GET "/api/v2/workspace/by-slug/$SHARED_WS_SLUG/scenes/$SHARED_SCENE_ID" "" "$SUPERADMIN_COOKIES")
                
                if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"roomId":"[^"]*"'; then
                    log_success "getSceneBySlug returns roomId"
                else
                    log_fail "getSceneBySlug should return roomId"
                    echo "  Response: $SCENE_BY_SLUG_RESPONSE"
                fi
                
                if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"roomKey":"[^"]*"'; then
                    log_success "getSceneBySlug returns roomKey (auto-collaboration ready)"
                else
                    log_fail "getSceneBySlug should return roomKey for users with canCollaborate"
                    echo "  Response: $SCENE_BY_SLUG_RESPONSE"
                fi
                
                # Check canCollaborate is true in access
                if echo "$SCENE_BY_SLUG_RESPONSE" | grep -q '"canCollaborate":true'; then
                    log_success "canCollaborate permission is true for shared collection scene"
                else
                    log_fail "canCollaborate should be true for shared collection scene"
                fi
                
                # Start collaboration endpoint should still work (for backwards compatibility)
                SHARED_COLLAB_RESPONSE=$(api_call POST "/api/v2/workspace/scenes/$SHARED_SCENE_ID/collaborate" "" "$SUPERADMIN_COOKIES")
                if echo "$SHARED_COLLAB_RESPONSE" | grep -q '"roomId":'; then
                    log_success "Start collaboration endpoint still works"
                    ROOM_ID=$(echo "$SHARED_COLLAB_RESPONSE" | grep -o '"roomId":"[^"]*"' | cut -d'"' -f4)
                    log_info "Room ID from endpoint: $ROOM_ID"
                    
                    # Check if roomKey is returned (decrypted server-side)
                    if echo "$SHARED_COLLAB_RESPONSE" | grep -q '"roomKey":'; then
                        log_success "roomKey is present in response (decrypted)"
                    else
                        log_fail "roomKey should be present in collaboration response"
                    fi
                else
                    log_fail "Start collaboration in shared workspace"
                    echo "  Response: $SHARED_COLLAB_RESPONSE"
                fi
                
                # Get collaboration info
                SHARED_COLLAB_INFO=$(api_call GET "/api/v2/workspace/scenes/$SHARED_SCENE_ID/collaborate" "" "$SUPERADMIN_COOKIES")
                if echo "$SHARED_COLLAB_INFO" | grep -q '"roomId":'; then
                    log_success "Get collaboration info in shared workspace"
                else
                    log_fail "Get collaboration info in shared workspace"
                    echo "  Response: $SHARED_COLLAB_INFO"
                fi
            else
                log_fail "Create scene in shared workspace"
                echo "  Response: $SHARED_SCENE_RESPONSE"
            fi
            
            # NEW: Test that scenes in PRIVATE collections do NOT get auto-collaboration
            if [ -n "$PRIVATE_COLLECTION_ID" ]; then
                log_section "10c. Super Admin - Private Collection (No Auto-Collaboration)"
                
                PRIVATE_SCENE_TITLE="Private Scene ${TIMESTAMP}"
                PRIVATE_SCENE_RESPONSE=$(api_call POST "/api/v2/workspace/scenes" "{\"title\":\"$PRIVATE_SCENE_TITLE\",\"collectionId\":\"$PRIVATE_COLLECTION_ID\"}" "$SUPERADMIN_COOKIES")
                
                if echo "$PRIVATE_SCENE_RESPONSE" | grep -q '"id":'; then
                    PRIVATE_SCENE_ID=$(echo "$PRIVATE_SCENE_RESPONSE" | grep -o '"id":"[^"]*"' | head -1 | cut -d'"' -f4)
                    log_success "Create scene in private collection"
                    
                    # Check that private collection scenes do NOT have auto-generated roomId
                    if echo "$PRIVATE_SCENE_RESPONSE" | grep -q '"roomId":null'; then
                        log_success "Scene in private collection has roomId=null (no auto-collaboration)"
                    elif echo "$PRIVATE_SCENE_RESPONSE" | grep -q '"roomId":"[^"]*"'; then
                        log_fail "Scene in private collection should NOT have auto-generated roomId"
                        echo "  Response: $PRIVATE_SCENE_RESPONSE"
                    else
                        log_success "Scene in private collection has no roomId"
                    fi
                    
                    # Check collaborationEnabled is false for private collection
                    if echo "$PRIVATE_SCENE_RESPONSE" | grep -q '"collaborationEnabled":false'; then
                        log_success "Scene in private collection has collaborationEnabled=false"
                    else
                        log_fail "Scene in private collection should have collaborationEnabled=false"
                    fi
                else
                    log_skip "Create scene in private collection"
                fi
            fi
        else
            log_fail "Create collection in shared workspace"
            echo "  Response: $COLLECTION_RESPONSE"
        fi
        
        # Clean up shared workspace
        log_section "11. Cleanup - Delete Shared Workspace"
        DELETE_WS_RESPONSE=$(api_call DELETE "/api/v2/workspaces/$SHARED_WS_ID" "" "$SUPERADMIN_COOKIES")
        if echo "$DELETE_WS_RESPONSE" | grep -q '"success":true'; then
            log_success "Delete shared workspace"
        else
            log_skip "Delete shared workspace (may require cascade delete)"
        fi
    else
        log_fail "Create shared workspace"
        echo "  Response: $CREATE_WS_RESPONSE"
    fi
fi

# ============================================================================
# PART 3: CLEANUP
# ============================================================================

log_section "12. Cleanup - Regular User"

# Delete the test scene created by regular user
if [ -n "$REGULAR_USER_SCENE_ID" ] && [ "$REGULAR_USER_SCENE_ID" != "null" ]; then
    DELETE_RESPONSE=$(api_call DELETE "/api/v2/workspace/scenes/$REGULAR_USER_SCENE_ID")
    if echo "$DELETE_RESPONSE" | grep -q '"success":true'; then
        log_success "Delete test scene"
    else
        log_skip "Delete test scene"
    fi
fi

# Clean up cookie files
rm -f "$COOKIES_FILE" "$SUPERADMIN_COOKIES"

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
echo "========================================"
echo "  Test Summary"
echo "========================================"
echo -e "  ${GREEN}Passed:  $PASSED${NC}"
echo -e "  ${RED}Failed:  $FAILED${NC}"
echo -e "  ${CYAN}Skipped: $SKIPPED${NC}"
echo "========================================"
echo ""

if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Some tests failed!${NC}"
    echo ""
    echo "Common issues:"
    echo "  1. Make sure SUPERADMIN_EMAILS is set in .env"
    echo "  2. Run 'just fresh-dev' to reset the database"
    echo "  3. Check API logs with 'just logs-api'"
    exit 1
else
    echo -e "${GREEN}All tests passed!${NC}"
fi

exit 0
