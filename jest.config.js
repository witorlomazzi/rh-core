const { jestConfig } = require('@salesforce/sfdx-lwc-jest/config');

module.exports = {
    ...jestConfig,
    modulePathIgnorePatterns: ['<rootDir>/.localdevserver', '<rootDir>/.sf-logs', '<rootDir>/.claude'],
    // demo/ tem testes proprios do Node (node --test) e .claude/ guarda worktrees de trabalho.
    testPathIgnorePatterns: [...(jestConfig.testPathIgnorePatterns || []), '<rootDir>/demo/', '<rootDir>/.claude/']
};
