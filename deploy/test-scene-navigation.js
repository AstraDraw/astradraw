#!/usr/bin/env node

/**
 * AstraDraw Scene Navigation Interactive Test Script
 * 
 * This script guides testers through all scene navigation test scenarios
 * and saves results to a timestamped markdown file.
 * 
 * Usage:
 *   node test-scene-navigation.js
 *   # or via just:
 *   just test-navigation
 */

const readline = require('readline');
const fs = require('fs');
const path = require('path');

// Colors for terminal output
const colors = {
  reset: '\x1b[0m',
  bold: '\x1b[1m',
  red: '\x1b[31m',
  green: '\x1b[32m',
  yellow: '\x1b[33m',
  blue: '\x1b[34m',
  cyan: '\x1b[36m',
};

// Results directory
const RESULTS_DIR = path.join(__dirname, 'test-results');

// Ensure results directory exists
if (!fs.existsSync(RESULTS_DIR)) {
  fs.mkdirSync(RESULTS_DIR, { recursive: true });
}

// Timestamp for this test run
const timestamp = new Date().toISOString().replace(/[:.]/g, '-').slice(0, 19);
const resultsFile = path.join(RESULTS_DIR, `scene-navigation-test_${timestamp}.md`);

// Counters
let passed = 0;
let failed = 0;
let skipped = 0;

// Configuration
let config = {
  domain: '',
  protocol: 'https',
  workspaceSlug: 'admin',
  userRole: 'Super Admin',
  testerName: '',
};

// Readline interface
const rl = readline.createInterface({
  input: process.stdin,
  output: process.stdout,
});

// Helper to ask questions
function ask(question) {
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      resolve(answer.trim());
    });
  });
}

// Helper to print colored text
function print(text, color = '') {
  console.log(color ? `${color}${text}${colors.reset}` : text);
}

function printHeader(text) {
  console.log('');
  print('═'.repeat(70), colors.cyan);
  print(`  ${text}`, colors.cyan);
  print('═'.repeat(70), colors.cyan);
  console.log('');
}

function printSection(text) {
  console.log('');
  print('─'.repeat(70), colors.blue);
  print(`  ${text}`, colors.blue);
  print('─'.repeat(70), colors.blue);
  console.log('');
}

function printTest(id, name) {
  print(`Test ${id}: ${name}`, colors.yellow);
}

function printSteps(steps) {
  print('Steps:', colors.bold);
  steps.forEach((step, i) => {
    console.log(`  ${i + 1}. ${step}`);
  });
}

function printExpected(text) {
  print(`Expected: ${text}`, colors.bold);
}

function printUrl(url) {
  print(`URL: ${colors.cyan}${url}${colors.reset}`, colors.bold);
}

function buildUrl(path) {
  return `${config.protocol}://${config.domain}${path}`;
}

// Write to results file
function writeResult(testId, testName, result, notes = '') {
  const resultEmoji = result === 'pass' ? '✅ Passed' : result === 'fail' ? '❌ Failed' : '⏭️ Skipped';
  fs.appendFileSync(resultsFile, `| ${testId} | ${testName} | ${resultEmoji} | ${notes} |\n`);
}

// Ask for test result
async function askResult(testId, testName) {
  console.log('');
  print('Result:', colors.bold);
  console.log('  [1] ✅ Passed');
  console.log('  [2] ❌ Failed');
  console.log('  [3] ⏭️  Skip');
  console.log('');
  
  const choice = await ask('Enter choice (1/2/3): ');
  let result = 'skip';
  let notes = '';
  
  switch (choice) {
    case '1':
      result = 'pass';
      passed++;
      print('✅ PASSED', colors.green);
      break;
    case '2':
      result = 'fail';
      failed++;
      print('❌ FAILED', colors.red);
      console.log('');
      notes = await ask('Describe what happened: ');
      break;
    case '3':
    default:
      result = 'skip';
      skipped++;
      print('⏭️  SKIPPED', colors.yellow);
      notes = await ask('Reason for skipping (optional): ');
      break;
  }
  
  writeResult(testId, testName, result, notes);
  console.log('');
  
  // Wait for user to continue
  await ask('Press Enter to continue...');
}

// Test definitions
const tests = {
  // Section 1: Login & Dashboard Redirect
  '1': {
    name: 'Login & Dashboard Redirect',
    tests: [
      {
        id: '1.1',
        name: 'Fresh login redirects to dashboard',
        steps: [
          'Clear cookies or use incognito/private window',
          () => `Open ${buildUrl('/')}`,
          'Log in with your credentials',
        ],
        expected: () => `After login, URL changes to /workspace/${config.workspaceSlug}/dashboard and dashboard is displayed`,
        url: () => buildUrl('/'),
      },
      {
        id: '1.2',
        name: 'Root URL redirects when logged in',
        steps: [
          () => `While logged in, navigate to ${buildUrl('/')}`,
          'Wait for redirect',
        ],
        expected: () => `URL changes to /workspace/${config.workspaceSlug}/dashboard`,
        url: () => buildUrl('/'),
      },
      {
        id: '1.3',
        name: 'Direct dashboard URL works',
        steps: [
          () => `Open ${buildUrl(`/workspace/${config.workspaceSlug}/dashboard`)} directly`,
        ],
        expected: 'Dashboard is displayed, URL stays the same',
        url: () => buildUrl(`/workspace/${config.workspaceSlug}/dashboard`),
      },
    ],
  },
  
  // Section 2: Scene Creation
  '2': {
    name: 'Scene Creation',
    tests: [
      {
        id: '2.1',
        name: 'Create scene from dashboard button',
        steps: [
          'Go to dashboard',
          "Click '+ Начать рисовать' button",
        ],
        expected: () => `New scene created, redirected to canvas with URL /workspace/${config.workspaceSlug}/scene/{id}`,
        url: () => buildUrl(`/workspace/${config.workspaceSlug}/dashboard`),
      },
      {
        id: '2.2',
        name: 'Create scene from sidebar (canvas mode)',
        steps: [
          'Open any scene (canvas mode)',
          "In sidebar, click '+' next to collection name",
        ],
        expected: 'New scene created in that collection, canvas updates, URL changes',
      },
      {
        id: '2.3',
        name: 'Scene appears in correct collection',
        steps: [
          'Note which collection the scene was created in',
          'Go to dashboard',
          'Click on that collection in sidebar',
        ],
        expected: 'New scene is visible in the collection',
      },
    ],
  },
  
  // Section 3: Scene Navigation
  '3': {
    name: 'Scene Navigation (Switching Between Scenes)',
    tests: [
      {
        id: '3.1',
        name: 'Switch scenes from sidebar',
        steps: [
          'Make sure you have 2+ scenes in a collection',
          'Open Scene A',
          'Click Scene B in sidebar',
        ],
        expected: 'URL changes to Scene B, canvas shows Scene B content',
      },
      {
        id: '3.2',
        name: 'Scene content is correct',
        steps: [
          'Create Scene A, draw a rectangle',
          'Create Scene B, draw a circle',
          'Switch between them multiple times',
        ],
        expected: 'Each scene shows its own content (rectangle/circle)',
      },
      {
        id: '3.3',
        name: 'Open scene from dashboard',
        steps: [
          'Go to dashboard',
          "Click on a scene card under 'Недавно изменённые вами'",
        ],
        expected: 'URL changes to scene URL, canvas shows scene content',
      },
      {
        id: '3.4',
        name: 'Rapid scene switching',
        steps: [
          'Have 3+ scenes',
          'Quickly click Scene A, then B, then C in rapid succession',
        ],
        expected: 'Final scene (C) is displayed, no errors in console',
      },
    ],
  },
  
  // Section 4: Scene Deletion
  '4': {
    name: 'Scene Deletion',
    tests: [
      {
        id: '4.1',
        name: 'Delete scene (others remain in collection)',
        steps: [
          'Have 2+ scenes in a collection',
          'Open Scene A',
          'Delete Scene A from sidebar (right-click or menu)',
        ],
        expected: 'Confirmation dialog appears, after confirm: switches to another scene in same collection',
      },
      {
        id: '4.2',
        name: 'Delete last scene in collection',
        steps: [
          'Have only 1 scene in a collection',
          'Open that scene',
          'Delete it',
        ],
        expected: 'After deletion, redirects to dashboard',
      },
      {
        id: '4.3',
        name: 'URL updates after deletion',
        steps: [
          'Delete current scene',
          'Check the URL in address bar',
        ],
        expected: 'URL shows new scene URL or dashboard URL (NOT the deleted scene URL)',
      },
      {
        id: '4.4',
        name: 'Back button after deletion',
        steps: [
          'Delete a scene (goes to dashboard or another scene)',
          'Click browser Back button',
        ],
        expected: 'Does NOT go back to deleted scene URL',
      },
    ],
  },
  
  // Section 5: Browser Navigation
  '5': {
    name: 'Browser Navigation (Back/Forward)',
    tests: [
      {
        id: '5.1',
        name: 'Back from scene to dashboard',
        steps: [
          'Go to dashboard',
          'Open a scene',
          'Click browser Back button',
        ],
        expected: 'Returns to dashboard, URL is dashboard URL',
      },
      {
        id: '5.2',
        name: 'Forward from dashboard to scene',
        steps: [
          'After test 5.1, click browser Forward button',
        ],
        expected: 'Returns to scene, URL is scene URL, content is correct',
      },
      {
        id: '5.3',
        name: 'Back between scenes',
        steps: [
          'Open Scene A',
          'Open Scene B',
          'Click browser Back button',
        ],
        expected: 'Returns to Scene A with correct content',
      },
    ],
  },
  
  // Section 6: Page Refresh
  '6': {
    name: 'Page Refresh',
    tests: [
      {
        id: '6.1',
        name: 'Refresh on scene',
        steps: [
          'Open a scene with content',
          'Press F5 or Cmd+R to refresh',
        ],
        expected: 'Same scene loads with same content',
      },
      {
        id: '6.2',
        name: 'Refresh on dashboard',
        steps: [
          'Go to dashboard',
          'Press F5 or Cmd+R to refresh',
        ],
        expected: 'Dashboard reloads, stays on dashboard',
      },
    ],
  },
  
  // Section 7: Direct URL Access
  '7': {
    name: 'Direct URL Access (Bookmarks)',
    tests: [
      {
        id: '7.1',
        name: 'Bookmark scene URL',
        steps: [
          'Copy a scene URL from address bar',
          'Close the tab',
          'Open the URL in a new tab',
        ],
        expected: 'Scene loads with correct content (after login if needed)',
      },
      {
        id: '7.2',
        name: 'Invalid scene URL',
        steps: [
          () => `Open URL with non-existent scene ID: ${buildUrl(`/workspace/${config.workspaceSlug}/scene/invalid-scene-id-12345`)}`,
          'Wait for load',
        ],
        expected: 'Error handled, redirects to dashboard',
        url: () => buildUrl(`/workspace/${config.workspaceSlug}/scene/invalid-scene-id-12345`),
      },
    ],
  },
  
  // Section 8: Collections
  '8': {
    name: 'Collections',
    tests: [
      {
        id: '8.1',
        name: 'Create new collection',
        steps: [
          "In sidebar, click '+' next to 'КОЛЛЕКЦИИ'",
          'Enter name and select icon',
          'Save',
        ],
        expected: 'New collection appears in sidebar',
      },
      {
        id: '8.2',
        name: 'Create scene in new collection',
        steps: [
          'Click on the new collection',
          'Create a scene in that collection',
        ],
        expected: 'Scene is created and visible in that collection',
      },
      {
        id: '8.3',
        name: 'Private collection always exists',
        steps: [
          "Check sidebar for 'Приватное' collection",
        ],
        expected: "'Приватное' collection is always present",
      },
    ],
  },
  
  // Section 9: Multiple Workspaces
  '9': {
    name: 'Multiple Workspaces',
    tests: [
      {
        id: '9.1',
        name: 'Create new workspace',
        steps: [
          'Click workspace dropdown in sidebar (top left)',
          "'Create workspace'",
          'Enter name and create',
        ],
        expected: 'New workspace created with private collection',
      },
      {
        id: '9.2',
        name: 'Switch workspaces',
        steps: [
          'Have 2+ workspaces',
          'Switch between them using dropdown',
        ],
        expected: 'Dashboard shows correct workspace, URL updates with new slug',
      },
      {
        id: '9.3',
        name: 'Scenes isolated per workspace',
        steps: [
          'Create scene in Workspace A',
          'Switch to Workspace B',
        ],
        expected: 'Scene from Workspace A is not visible in Workspace B',
      },
    ],
  },
  
  // Section 10: Anonymous Mode
  '10': {
    name: 'Anonymous Mode',
    tests: [
      {
        id: '10.1',
        name: 'Anonymous mode works',
        steps: [
          () => `Open ${buildUrl('/?mode=anonymous')}`,
        ],
        expected: 'Canvas is displayed (not dashboard), no login required',
        url: () => buildUrl('/?mode=anonymous'),
      },
      {
        id: '10.2',
        name: "'Создать анонимную доску' button",
        steps: [
          "While logged in, click 'Создать анонимную доску' in sidebar",
        ],
        expected: 'Opens anonymous canvas',
      },
    ],
  },
  
  // Section 11: Auto-save
  '11': {
    name: 'Auto-save',
    tests: [
      {
        id: '11.1',
        name: 'Changes auto-save',
        steps: [
          'Open a scene',
          'Draw something new',
          'Wait 5 seconds',
          'Refresh page (F5)',
        ],
        expected: 'Drawing is preserved after refresh',
      },
    ],
  },
};

// Main function
async function main() {
  console.clear();
  printHeader('AstraDraw Scene Navigation Test Suite');
  
  console.log('This interactive script will guide you through testing the scene');
  console.log('navigation feature. Results will be saved to:');
  print(resultsFile, colors.cyan);
  console.log('');
  
  // Get tester name
  config.testerName = await ask('Enter your name (for the report): ') || 'Anonymous';
  
  // Get domain
  console.log('');
  print('Enter your AstraDraw domain', colors.bold);
  console.log('Examples: 10.100.0.10, localhost, app.astradraw.com');
  config.domain = await ask('Domain: ') || 'localhost';
  
  // Get protocol
  console.log('');
  const protocolChoice = await ask('Protocol (https/http) [https]: ');
  config.protocol = protocolChoice || 'https';
  
  // Get workspace slug
  console.log('');
  print('Enter your workspace slug', colors.bold);
  console.log("This is usually 'admin' for the default workspace");
  config.workspaceSlug = await ask('Workspace slug [admin]: ') || 'admin';
  
  // Get user role
  console.log('');
  print('What role are you testing as?', colors.bold);
  console.log('  [1] Super Admin (can manage everything)');
  console.log('  [2] Workspace Admin');
  console.log('  [3] Regular Member');
  const roleChoice = await ask('Enter choice [1]: ');
  switch (roleChoice) {
    case '2': config.userRole = 'Workspace Admin'; break;
    case '3': config.userRole = 'Regular Member'; break;
    default: config.userRole = 'Super Admin';
  }
  
  // Initialize results file
  const header = `# Scene Navigation Test Results

**Tester:** ${config.testerName}  
**Date:** ${new Date().toISOString()}  
**Domain:** ${config.protocol}://${config.domain}  
**Workspace:** ${config.workspaceSlug}  
**Role:** ${config.userRole}  

---

## Test Results

| Test # | Test Name | Result | Notes |
|--------|-----------|--------|-------|
`;
  fs.writeFileSync(resultsFile, header);
  
  console.log('');
  print('Configuration saved!', colors.green);
  console.log('');
  console.log(`Base URL: ${buildUrl('')}`);
  console.log(`Dashboard: ${buildUrl(`/workspace/${config.workspaceSlug}/dashboard`)}`);
  console.log('');
  await ask('Press Enter to start testing...');
  
  // Run tests
  for (const [sectionNum, section] of Object.entries(tests)) {
    printSection(`${sectionNum}. ${section.name}`);
    fs.appendFileSync(resultsFile, `\n## ${sectionNum}. ${section.name}\n\n`);
    
    for (const test of section.tests) {
      printTest(test.id, test.name);
      
      // Print steps
      const steps = test.steps.map(s => typeof s === 'function' ? s() : s);
      printSteps(steps);
      
      // Print expected
      const expected = typeof test.expected === 'function' ? test.expected() : test.expected;
      printExpected(expected);
      
      // Print URL if available
      if (test.url) {
        printUrl(typeof test.url === 'function' ? test.url() : test.url);
      }
      
      await askResult(test.id, test.name);
    }
  }
  
  // Summary
  printHeader('Test Summary');
  
  const total = passed + failed + skipped;
  print(`Passed:  ${passed}`, colors.green);
  print(`Failed:  ${failed}`, colors.red);
  print(`Skipped: ${skipped}`, colors.yellow);
  print(`Total:   ${total}`, colors.bold);
  console.log('');
  
  // Add summary to results file
  const summary = `
---

## Summary

| Status | Count |
|--------|-------|
| ✅ Passed | ${passed} |
| ❌ Failed | ${failed} |
| ⏭️ Skipped | ${skipped} |
| **Total** | **${total}** |

---

## Issues Found

_List any issues that need to be fixed:_

`;
  fs.appendFileSync(resultsFile, summary);
  
  // Ask for additional notes
  console.log('');
  const additionalNotes = await ask('Any additional notes for this test run? ');
  if (additionalNotes) {
    fs.appendFileSync(resultsFile, `\n## Additional Notes\n\n${additionalNotes}\n`);
  }
  
  console.log('');
  print(`Results saved to: ${resultsFile}`, colors.green);
  console.log('');
  
  if (failed > 0) {
    print('Failed tests require attention!', colors.red);
    console.log('Review the results file for details.');
  }
  
  console.log('');
  console.log('Thank you for testing! 🎉');
  
  rl.close();
}

// Run
main().catch((err) => {
  console.error('Error:', err);
  rl.close();
  process.exit(1);
});


