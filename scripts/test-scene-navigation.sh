#!/bin/bash

# =============================================================================
# AstraDraw Scene Navigation Interactive Test Script
# =============================================================================
# This script guides testers through all scene navigation test scenarios
# and saves results to a timestamped file.
# =============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Results directory
RESULTS_DIR="test-results"
mkdir -p "$RESULTS_DIR"

# Timestamp for this test run
TIMESTAMP=$(date +"%Y-%m-%d_%H-%M-%S")
RESULTS_FILE="$RESULTS_DIR/scene-navigation-test_$TIMESTAMP.md"

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Configuration (will be set by user)
DOMAIN=""
PROTOCOL="https"
WORKSPACE_SLUG=""
USER_ROLE=""
TESTER_NAME=""

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════════════════════${NC}"
    echo ""
}

print_section() {
    echo ""
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}───────────────────────────────────────────────────────────────────${NC}"
    echo ""
}

print_test() {
    echo -e "${YELLOW}Test $1:${NC} $2"
}

print_steps() {
    echo -e "${BOLD}Steps:${NC}"
    echo "$1" | while IFS= read -r line; do
        echo -e "  $line"
    done
}

print_expected() {
    echo -e "${BOLD}Expected:${NC} $1"
}

print_url() {
    echo -e "${BOLD}URL:${NC} ${CYAN}$1${NC}"
}

print_result() {
    if [ "$1" == "pass" ]; then
        echo -e "${GREEN}✅ PASSED${NC}"
    elif [ "$1" == "fail" ]; then
        echo -e "${RED}❌ FAILED${NC}"
    else
        echo -e "${YELLOW}⏭️  SKIPPED${NC}"
    fi
}

# Ask for test result
ask_result() {
    local test_id="$1"
    local test_name="$2"
    
    echo ""
    echo -e "${BOLD}Result:${NC}"
    echo "  [1] ✅ Passed"
    echo "  [2] ❌ Failed"
    echo "  [3] ⏭️  Skip"
    echo ""
    read -p "Enter choice (1/2/3): " choice
    
    local result=""
    local notes=""
    
    case $choice in
        1)
            result="pass"
            PASSED=$((PASSED + 1))
            print_result "pass"
            ;;
        2)
            result="fail"
            FAILED=$((FAILED + 1))
            print_result "fail"
            echo ""
            read -p "Describe what happened: " notes
            ;;
        3)
            result="skip"
            SKIPPED=$((SKIPPED + 1))
            print_result "skip"
            read -p "Reason for skipping (optional): " notes
            ;;
        *)
            result="skip"
            SKIPPED=$((SKIPPED + 1))
            print_result "skip"
            ;;
    esac
    
    # Save to results file
    if [ "$result" == "pass" ]; then
        echo "| $test_id | $test_name | ✅ Passed | |" >> "$RESULTS_FILE"
    elif [ "$result" == "fail" ]; then
        echo "| $test_id | $test_name | ❌ Failed | $notes |" >> "$RESULTS_FILE"
    else
        echo "| $test_id | $test_name | ⏭️ Skipped | $notes |" >> "$RESULTS_FILE"
    fi
    
    echo ""
}

# Build URL helper
build_url() {
    echo "${PROTOCOL}://${DOMAIN}$1"
}

# =============================================================================
# Setup
# =============================================================================

clear
print_header "AstraDraw Scene Navigation Test Suite"

echo "This interactive script will guide you through testing the scene"
echo "navigation feature. Results will be saved to: $RESULTS_FILE"
echo ""

# Get tester name
read -p "Enter your name (for the report): " TESTER_NAME
TESTER_NAME=${TESTER_NAME:-"Anonymous"}

# Get domain
echo ""
echo -e "${BOLD}Enter your AstraDraw domain${NC}"
echo "Examples: 10.100.0.10, localhost, app.astradraw.com"
read -p "Domain: " DOMAIN
DOMAIN=${DOMAIN:-"localhost"}

# Get protocol
echo ""
read -p "Protocol (https/http) [https]: " PROTOCOL
PROTOCOL=${PROTOCOL:-"https"}

# Get workspace slug
echo ""
echo -e "${BOLD}Enter your workspace slug${NC}"
echo "This is usually 'admin' for the default workspace"
read -p "Workspace slug [admin]: " WORKSPACE_SLUG
WORKSPACE_SLUG=${WORKSPACE_SLUG:-"admin"}

# Get user role
echo ""
echo -e "${BOLD}What role are you testing as?${NC}"
echo "  [1] Super Admin (can manage everything)"
echo "  [2] Workspace Admin"
echo "  [3] Regular Member"
read -p "Enter choice [1]: " role_choice
case $role_choice in
    2) USER_ROLE="Workspace Admin" ;;
    3) USER_ROLE="Regular Member" ;;
    *) USER_ROLE="Super Admin" ;;
esac

# Initialize results file
cat > "$RESULTS_FILE" << EOF
# Scene Navigation Test Results

**Tester:** $TESTER_NAME  
**Date:** $(date +"%Y-%m-%d %H:%M:%S")  
**Domain:** ${PROTOCOL}://${DOMAIN}  
**Workspace:** $WORKSPACE_SLUG  
**Role:** $USER_ROLE  

---

## Test Results

| Test # | Test Name | Result | Notes |
|--------|-----------|--------|-------|
EOF

echo ""
echo -e "${GREEN}Configuration saved!${NC}"
echo ""
echo "Base URL: $(build_url '')"
echo "Dashboard: $(build_url "/workspace/$WORKSPACE_SLUG/dashboard")"
echo ""
read -p "Press Enter to start testing..."

# =============================================================================
# Section 1: Login & Dashboard Redirect
# =============================================================================

print_section "1. Login & Dashboard Redirect"

echo "## 1. Login & Dashboard Redirect" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 1.1
print_test "1.1" "Fresh login redirects to dashboard"
print_steps "1. Clear cookies or use incognito/private window
2. Open $(build_url '/')
3. Log in with your credentials"
print_expected "After login, URL changes to /workspace/$WORKSPACE_SLUG/dashboard and dashboard is displayed"
print_url "$(build_url '/')"
ask_result "1.1" "Fresh login redirects to dashboard"

# Test 1.2
print_test "1.2" "Root URL redirects when logged in"
print_steps "1. While logged in, navigate to $(build_url '/')
2. Wait for redirect"
print_expected "URL changes to /workspace/$WORKSPACE_SLUG/dashboard"
print_url "$(build_url '/')"
ask_result "1.2" "Root URL redirects when logged in"

# Test 1.3
print_test "1.3" "Direct dashboard URL works"
print_steps "1. Open $(build_url "/workspace/$WORKSPACE_SLUG/dashboard") directly"
print_expected "Dashboard is displayed, URL stays the same"
print_url "$(build_url "/workspace/$WORKSPACE_SLUG/dashboard")"
ask_result "1.3" "Direct dashboard URL works"

# =============================================================================
# Section 2: Scene Creation
# =============================================================================

print_section "2. Scene Creation"

echo "" >> "$RESULTS_FILE"
echo "## 2. Scene Creation" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 2.1
print_test "2.1" "Create scene from dashboard button"
print_steps "1. Go to dashboard
2. Click '+ Начать рисовать' button"
print_expected "New scene created, redirected to canvas with URL /workspace/$WORKSPACE_SLUG/scene/{id}"
print_url "$(build_url "/workspace/$WORKSPACE_SLUG/dashboard")"
ask_result "2.1" "Create scene from dashboard button"

# Test 2.2
print_test "2.2" "Create scene from sidebar (canvas mode)"
print_steps "1. Open any scene (canvas mode)
2. In sidebar, click '+' next to collection name"
print_expected "New scene created in that collection, canvas updates, URL changes"
ask_result "2.2" "Create scene from sidebar"

# Test 2.3
print_test "2.3" "Scene appears in correct collection"
print_steps "1. Note which collection the scene was created in
2. Go to dashboard
3. Click on that collection in sidebar"
print_expected "New scene is visible in the collection"
ask_result "2.3" "Scene appears in correct collection"

# =============================================================================
# Section 3: Scene Navigation
# =============================================================================

print_section "3. Scene Navigation (Switching Between Scenes)"

echo "" >> "$RESULTS_FILE"
echo "## 3. Scene Navigation" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 3.1
print_test "3.1" "Switch scenes from sidebar"
print_steps "1. Make sure you have 2+ scenes in a collection
2. Open Scene A
3. Click Scene B in sidebar"
print_expected "URL changes to Scene B, canvas shows Scene B content"
ask_result "3.1" "Switch scenes from sidebar"

# Test 3.2
print_test "3.2" "Scene content is correct"
print_steps "1. Create Scene A, draw a rectangle
2. Create Scene B, draw a circle
3. Switch between them multiple times"
print_expected "Each scene shows its own content (rectangle/circle)"
ask_result "3.2" "Scene content is correct"

# Test 3.3
print_test "3.3" "Open scene from dashboard"
print_steps "1. Go to dashboard
2. Click on a scene card under 'Недавно изменённые вами'"
print_expected "URL changes to scene URL, canvas shows scene content"
ask_result "3.3" "Open scene from dashboard"

# Test 3.4
print_test "3.4" "Open scene from collection view"
print_steps "1. Go to dashboard
2. Click on a collection in sidebar
3. Click on a scene in that collection"
print_expected "URL changes to scene URL, canvas shows scene content"
ask_result "3.4" "Open scene from collection view"

# Test 3.5
print_test "3.5" "Rapid scene switching"
print_steps "1. Have 3+ scenes
2. Quickly click Scene A, then B, then C in rapid succession"
print_expected "Final scene (C) is displayed, no errors in console"
ask_result "3.5" "Rapid scene switching"

# =============================================================================
# Section 4: Scene Deletion
# =============================================================================

print_section "4. Scene Deletion"

echo "" >> "$RESULTS_FILE"
echo "## 4. Scene Deletion" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 4.1
print_test "4.1" "Delete scene (others remain in collection)"
print_steps "1. Have 2+ scenes in a collection
2. Open Scene A
3. Delete Scene A from sidebar (right-click or menu)"
print_expected "Confirmation dialog appears, after confirm: switches to another scene in same collection"
ask_result "4.1" "Delete scene (others remain)"

# Test 4.2
print_test "4.2" "Delete last scene in collection"
print_steps "1. Have only 1 scene in a collection
2. Open that scene
3. Delete it"
print_expected "After deletion, redirects to dashboard"
ask_result "4.2" "Delete last scene in collection"

# Test 4.3
print_test "4.3" "URL updates after deletion"
print_steps "1. Delete current scene
2. Check the URL in address bar"
print_expected "URL shows new scene URL or dashboard URL (NOT the deleted scene URL)"
ask_result "4.3" "URL updates after deletion"

# Test 4.4
print_test "4.4" "Back button after deletion"
print_steps "1. Delete a scene (goes to dashboard or another scene)
2. Click browser Back button"
print_expected "Does NOT go back to deleted scene URL"
ask_result "4.4" "Back button after deletion"

# =============================================================================
# Section 5: Browser Navigation
# =============================================================================

print_section "5. Browser Navigation (Back/Forward)"

echo "" >> "$RESULTS_FILE"
echo "## 5. Browser Navigation" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 5.1
print_test "5.1" "Back from scene to dashboard"
print_steps "1. Go to dashboard
2. Open a scene
3. Click browser Back button"
print_expected "Returns to dashboard, URL is dashboard URL"
ask_result "5.1" "Back from scene to dashboard"

# Test 5.2
print_test "5.2" "Forward from dashboard to scene"
print_steps "1. After test 5.1, click browser Forward button"
print_expected "Returns to scene, URL is scene URL, content is correct"
ask_result "5.2" "Forward from dashboard to scene"

# Test 5.3
print_test "5.3" "Back between scenes"
print_steps "1. Open Scene A
2. Open Scene B
3. Click browser Back button"
print_expected "Returns to Scene A with correct content"
ask_result "5.3" "Back between scenes"

# Test 5.4
print_test "5.4" "Multiple back/forward"
print_steps "1. Navigate: Dashboard → Scene A → Scene B → Dashboard
2. Click Back 3 times
3. Click Forward 3 times"
print_expected "Navigation works correctly through all states"
ask_result "5.4" "Multiple back/forward"

# =============================================================================
# Section 6: Page Refresh
# =============================================================================

print_section "6. Page Refresh"

echo "" >> "$RESULTS_FILE"
echo "## 6. Page Refresh" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 6.1
print_test "6.1" "Refresh on scene"
print_steps "1. Open a scene with content
2. Press F5 or Cmd+R to refresh"
print_expected "Same scene loads with same content"
ask_result "6.1" "Refresh on scene"

# Test 6.2
print_test "6.2" "Refresh on dashboard"
print_steps "1. Go to dashboard
2. Press F5 or Cmd+R to refresh"
print_expected "Dashboard reloads, stays on dashboard"
ask_result "6.2" "Refresh on dashboard"

# Test 6.3
print_test "6.3" "Refresh on collection view"
print_steps "1. Click on a collection to view it
2. Press F5 or Cmd+R to refresh"
print_expected "Collection view reloads correctly"
ask_result "6.3" "Refresh on collection view"

# =============================================================================
# Section 7: Direct URL Access (Bookmarks)
# =============================================================================

print_section "7. Direct URL Access (Bookmarks)"

echo "" >> "$RESULTS_FILE"
echo "## 7. Direct URL Access" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 7.1
print_test "7.1" "Bookmark scene URL"
print_steps "1. Copy a scene URL from address bar
2. Close the tab
3. Open the URL in a new tab"
print_expected "Scene loads with correct content (after login if needed)"
ask_result "7.1" "Bookmark scene URL"

# Test 7.2
print_test "7.2" "Bookmark dashboard URL"
print_steps "1. Copy dashboard URL
2. Open in new tab"
print_expected "Dashboard loads correctly"
print_url "$(build_url "/workspace/$WORKSPACE_SLUG/dashboard")"
ask_result "7.2" "Bookmark dashboard URL"

# Test 7.3
print_test "7.3" "Invalid scene URL"
print_steps "1. Open URL with non-existent scene ID:
   $(build_url "/workspace/$WORKSPACE_SLUG/scene/invalid-scene-id-12345")
2. Wait for load"
print_expected "Error handled, redirects to dashboard"
print_url "$(build_url "/workspace/$WORKSPACE_SLUG/scene/invalid-scene-id-12345")"
ask_result "7.3" "Invalid scene URL"

# =============================================================================
# Section 8: Collections
# =============================================================================

print_section "8. Collections"

echo "" >> "$RESULTS_FILE"
echo "## 8. Collections" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 8.1
print_test "8.1" "Create new collection"
print_steps "1. In sidebar, click '+' next to 'КОЛЛЕКЦИИ'
2. Enter name and select icon
3. Save"
print_expected "New collection appears in sidebar"
ask_result "8.1" "Create new collection"

# Test 8.2
print_test "8.2" "Create scene in new collection"
print_steps "1. Click on the new collection
2. Create a scene in that collection"
print_expected "Scene is created and visible in that collection"
ask_result "8.2" "Create scene in new collection"

# Test 8.3
print_test "8.3" "Switch between collections"
print_steps "1. Have scenes in 2+ collections
2. Click on different collections in sidebar"
print_expected "Correct scenes shown for each collection"
ask_result "8.3" "Switch between collections"

# Test 8.4
print_test "8.4" "Private collection always exists"
print_steps "1. Check sidebar for 'Приватное' collection"
print_expected "'Приватное' collection is always present"
ask_result "8.4" "Private collection exists"

# =============================================================================
# Section 9: Multiple Workspaces
# =============================================================================

print_section "9. Multiple Workspaces"

echo "" >> "$RESULTS_FILE"
echo "## 9. Multiple Workspaces" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 9.1
print_test "9.1" "Create new workspace"
print_steps "1. Click workspace dropdown in sidebar (top left)
2. Click 'Create workspace'
3. Enter name and create"
print_expected "New workspace created with private collection"
ask_result "9.1" "Create new workspace"

# Test 9.2
print_test "9.2" "Switch workspaces"
print_steps "1. Have 2+ workspaces
2. Switch between them using dropdown"
print_expected "Dashboard shows correct workspace, URL updates with new slug"
ask_result "9.2" "Switch workspaces"

# Test 9.3
print_test "9.3" "Scenes isolated per workspace"
print_steps "1. Create scene in Workspace A
2. Switch to Workspace B"
print_expected "Scene from Workspace A is not visible in Workspace B"
ask_result "9.3" "Scenes isolated per workspace"

# Test 9.4
print_test "9.4" "URL reflects workspace"
print_steps "1. Switch workspaces
2. Check URL"
print_expected "URL contains correct workspace slug"
ask_result "9.4" "URL reflects workspace"

# =============================================================================
# Section 10: Anonymous Mode
# =============================================================================

print_section "10. Anonymous Mode"

echo "" >> "$RESULTS_FILE"
echo "## 10. Anonymous Mode" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 10.1
print_test "10.1" "Anonymous mode works"
print_steps "1. Open $(build_url '/?mode=anonymous')"
print_expected "Canvas is displayed (not dashboard), no login required"
print_url "$(build_url '/?mode=anonymous')"
ask_result "10.1" "Anonymous mode works"

# Test 10.2
print_test "10.2" "Anonymous mode is separate"
print_steps "1. Draw something in anonymous mode
2. Log in
3. Go to dashboard"
print_expected "Anonymous drawing is NOT in workspace scenes"
ask_result "10.2" "Anonymous mode is separate"

# Test 10.3
print_test "10.3" "'Создать анонимную доску' button"
print_steps "1. While logged in, click 'Создать анонимную доску' in sidebar"
print_expected "Opens anonymous canvas"
ask_result "10.3" "Anonymous board button"

# =============================================================================
# Section 11: Auto-save
# =============================================================================

print_section "11. Auto-save"

echo "" >> "$RESULTS_FILE"
echo "## 11. Auto-save" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 11.1
print_test "11.1" "Changes auto-save"
print_steps "1. Open a scene
2. Draw something new
3. Wait 5 seconds
4. Refresh page (F5)"
print_expected "Drawing is preserved after refresh"
ask_result "11.1" "Changes auto-save"

# Test 11.2
print_test "11.2" "Changes persist across sessions"
print_steps "1. Draw in a scene
2. Log out
3. Log back in
4. Open same scene"
print_expected "Drawing is preserved"
ask_result "11.2" "Changes persist across sessions"

# =============================================================================
# Section 12: Error Handling
# =============================================================================

print_section "12. Error Handling"

echo "" >> "$RESULTS_FILE"
echo "## 12. Error Handling" >> "$RESULTS_FILE"
echo "" >> "$RESULTS_FILE"

# Test 12.1
print_test "12.1" "Deleted scene URL access"
print_steps "1. Create a scene and copy its URL
2. Delete that scene
3. Paste the URL and navigate to it"
print_expected "Error handled gracefully, redirects to dashboard"
ask_result "12.1" "Deleted scene URL access"

# =============================================================================
# Summary
# =============================================================================

print_header "Test Summary"

TOTAL=$((PASSED + FAILED + SKIPPED))

echo -e "${GREEN}Passed:${NC}  $PASSED"
echo -e "${RED}Failed:${NC}  $FAILED"
echo -e "${YELLOW}Skipped:${NC} $SKIPPED"
echo -e "${BOLD}Total:${NC}   $TOTAL"
echo ""

# Add summary to results file
cat >> "$RESULTS_FILE" << EOF

---

## Summary

| Status | Count |
|--------|-------|
| ✅ Passed | $PASSED |
| ❌ Failed | $FAILED |
| ⏭️ Skipped | $SKIPPED |
| **Total** | **$TOTAL** |

---

## Issues Found

_List any issues that need to be fixed:_

EOF

# Ask for additional notes
echo ""
read -p "Any additional notes for this test run? " additional_notes
if [ -n "$additional_notes" ]; then
    echo "" >> "$RESULTS_FILE"
    echo "## Additional Notes" >> "$RESULTS_FILE"
    echo "" >> "$RESULTS_FILE"
    echo "$additional_notes" >> "$RESULTS_FILE"
fi

echo ""
echo -e "${GREEN}Results saved to:${NC} $RESULTS_FILE"
echo ""

# Show failed tests if any
if [ $FAILED -gt 0 ]; then
    echo -e "${RED}Failed tests require attention!${NC}"
    echo "Review the results file for details."
fi

echo ""
echo "Thank you for testing! 🎉"

