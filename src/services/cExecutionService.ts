export type ExecutionStatus = 'PASS' | 'FAIL' | 'COMPILATION_ERROR' | 'RUNTIME_ERROR' | 'TIMEOUT'

export type CTestCase = {
  id: string
  input: string
  expectedOutput: string
  marks: number
}

export type CExecutionResult = {
  status: ExecutionStatus
  actualOutput?: string
  compileOutput?: string
  error?: string
  executionTimeMs?: number
  score: number
  testCaseId?: string
}

export interface CExecutionService {
  compile(sourceCode: string): Promise<CExecutionResult>
  run(sourceCode: string, input: string): Promise<CExecutionResult>
  runTestCase(sourceCode: string, testCase: CTestCase): Promise<CExecutionResult>
  runTestCases(sourceCode: string, testCases: CTestCase[]): Promise<CExecutionResult[]>
}

/**
 * Deliberately refuses to execute source in the SPA. Replace this adapter with
 * a trusted WebAssembly runner or a separately hosted sandbox API.
 */
export class UnconfiguredCExecutionService implements CExecutionService {
  private unavailable(): Promise<CExecutionResult> {
    return Promise.resolve({
      status: 'RUNTIME_ERROR',
      error: 'C execution is not configured. Connect a sandboxed runner before enabling execution.',
      score: 0,
    })
  }

  compile(_sourceCode: string) { return this.unavailable() }
  run(_sourceCode: string, _input: string) { return this.unavailable() }
  runTestCase(_sourceCode: string, _testCase: CTestCase) { return this.unavailable() }
  runTestCases(_sourceCode: string, _testCases: CTestCase[]) { return Promise.resolve([]) }
}

export const cExecutionService: CExecutionService = new UnconfiguredCExecutionService()
