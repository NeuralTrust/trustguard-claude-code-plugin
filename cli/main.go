// Command trustguard-claude-code bridges Claude Code agent hooks with the TrustGuard
// data-plane API. Claude Code invokes it per hook event (stdin JSON in, stdout JSON
// out); the binary maps each event to POST /v1/evaluate and translates the
// guard verdict into the Claude Code hook contract.
//
// Subcommands:
//
//	hook     read one hook event from stdin, evaluate it, answer on stdout (default)
//	version  print the integration version
//
// The binary talks exclusively to the data plane (/v1/evaluate) with a
// collector API key; guards, detectors and policies are configured by an
// admin in the NeuralTrust app.
package main

import (
	"fmt"
	"os"
)

const integrationVersion = "0.1.16"

func main() {
	cmd := "hook"
	if len(os.Args) > 1 {
		cmd = os.Args[1]
	}

	var err error
	switch cmd {
	case "hook":
		err = runHook(os.Stdin, os.Stdout, loadConfig())
	case "version":
		fmt.Println(integrationVersion)
	case "help", "-h", "--help":
		printUsage()
	default:
		fmt.Fprintf(os.Stderr, "unknown subcommand %q\n\n", cmd)
		printUsage()
		os.Exit(2)
	}
	if err != nil {
		fmt.Fprintf(os.Stderr, "trustguard-claude-code %s: %v\n", cmd, err)
		os.Exit(1)
	}
}

func printUsage() {
	fmt.Print(`trustguard-claude-code — TrustGuard integration for Claude Code agent hooks

Usage:
  trustguard-claude-code [hook]            evaluate one hook event (stdin JSON → stdout JSON)
  trustguard-claude-code version           print version

Runtime configuration (env wins over ~/.trustguard/claude-code.json, except when
MDM managed mode locks api_key/data_url/fail_mode):
  TRUSTGUARD_DATA_URL      data-plane base URL   (default http://localhost:8081)
  TRUSTGUARD_API_KEY       org Claude Code collector API key (tgk_…)
  TRUSTGUARD_FAIL_MODE     open|closed on guard errors (default open)
  TRUSTGUARD_TIMEOUT_MS    evaluate timeout in ms      (default 5000)
  TRUSTGUARD_CLAUDE_CODE_CONFIG  alternative config file path
`)
}
