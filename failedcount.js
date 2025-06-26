const fs = require('fs');

// Files to process
const files = [
  { filename: 'failed_to_add.log', label: 'adding' },
  { filename: 'failed_to_remove.log', label: 'removal' },
  { filename: 'failed_to_increase_stake.txt', label: 'increasing' },
  { filename: 'failed_to_decrease_stake.txt', label: 'decreasing' }
];

// Function to get line count of a file
function getLineCount(filePath) {
  try {
    const data = fs.readFileSync(filePath, 'utf8');
    // Split by newline, filter out empty lines
    const lines = data.split(/\r?\n/).filter(line => line.trim() !== '');
    return lines.length;
  } catch (err) {
    console.error(`Error reading file ${filePath}:`, err.message);
    return 0;
  }
}

// Collect counts
const counts = files.map(file => ({
  label: file.label,
  count: getLineCount(file.filename)
}));

// Print header
console.log('Failures\n');

console.log('| adding | removal | increasing | decreasing |');

// Print dashed line
console.log('|--------|---------|------------|------------|');

// Print data row
console.log(
  `| ${counts[0].count.toString().padStart(6)} | ` +
  `${counts[1].count.toString().padStart(7)} | ` +
  `${counts[2].count.toString().padStart(10)} | ` +
  `${counts[3].count.toString().padStart(10)} |`
);
