package main

import (
	"crypto/rand"
	"fmt"
	"io"
	"math/big"
	"net/http"
	"os"
	"strconv"
)

const (
	specialChars = "!@#$%^&*()-_=+[]{}|;:,.<>?"
	numbers      = "0123456789"
	lowercase    = "abcdefghijklmnopqrstuvwxyz"
	uppercase    = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
)

// generatePassword generates a strong password of the specified length with the required constraints
func generatePassword(length int) (string, error) {
	if length < 10 {
		return "", fmt.Errorf("password length must be at least 10")
	}

	// Ensure password contains at least one of each required character type
	required := []string{specialChars, numbers, lowercase, uppercase}
	password := make([]byte, length)

	requiredIndexs := make(map[int64]byte)
	// Add one character of each type
	for i := 0; i < len(required); i++ {
		char, err := randomChar(required[i])
		if err != nil {
			return "", err
		}
		index, err := rand.Int(rand.Reader, big.NewInt(int64(length)))
		if err != nil {
			return "", err
		}
		requiredIndexs[index.Int64()] = char
		password[index.Int64()] = char
	}

	// Fill the rest with random characters from the full character set
	allChars := specialChars + numbers + lowercase + uppercase
	for i := 0; i < length; i++ {
		if _, exist := requiredIndexs[int64(i)]; exist {
			continue
		}
		char, err := randomChar(allChars)
		if err != nil {
			return "", err
		}
		password[i] = char
	}

	// Shuffle the password to ensure randomness
	shuffled := shuffle(password)

	return string(shuffled), nil
}

// randomChar selects a random character from the given string
func randomChar(charSet string) (byte, error) {
	index, err := rand.Int(rand.Reader, big.NewInt(int64(len(charSet))))
	if err != nil {
		return 0, fmt.Errorf("failed to generate random index: %w", err)
	}
	return charSet[index.Int64()], nil
}

// shuffle randomizes the order of characters in a slice
func shuffle(chars []byte) []byte {
	for i := range chars {
		j, _ := rand.Int(rand.Reader, big.NewInt(int64(len(chars))))
		chars[i], chars[j.Int64()] = chars[j.Int64()], chars[i]
	}
	return chars
}

// handlePasswordRequest serves HTTP requests for password generation
func handlePasswordRequest(w http.ResponseWriter, r *http.Request) {
	// Get the "length" parameter from the query string
	lengthStr := r.URL.Query().Get("length")
	if lengthStr == "" {
		lengthStr = "16" // Default length
	}

	// Parse the length as an integer
	length, err := strconv.Atoi(lengthStr)
	if err != nil || length < 10 {
		http.Error(w, "Invalid length parameter. Must be at least 10.", http.StatusBadRequest)
		return
	}

	// Generate the password
	password, err := generatePassword(length)
	if err != nil {
		http.Error(w, err.Error(), http.StatusInternalServerError)
		return
	}

	html := fmt.Sprintf(`<!DOCTYPE html>
<html>
<head>
<title>Password Generator</title>
<script>
function copyToClipboard() {
	const passwordField = document.getElementById("password");
	navigator.clipboard.writeText(passwordField.textContent).then(() => {
		alert("Password copied to clipboard!");
	}).catch(err => {
		alert("Failed to copy password: " + err);
	});
}
</script>
</head>
<body>
<h1>Strong Password Generator</h1>
<form method="get">
	<label for="length">Password Length:</label>
	<input type="number" id="length" name="length" value="%d" min="10">
	<button type="submit">Generate</button>
</form>
<h2>Generated Password:</h2>
<p id="password" style="font-family: monospace; font-size: 1.2em;">%s</p>
<button onclick="copyToClipboard()">Copy to Clipboard</button>
</body>
</html>`, length, password)

	w.Header().Set("Content-Type", "text/html")
	io.WriteString(w, html)
}

func main() {
	if len(os.Args) > 1 {
		// Command-line mode
		length, err := strconv.Atoi(os.Args[1])
		if err != nil || length < 10 {
			fmt.Println("Usage: go run main.go [length] (length must be at least 10)")
			return
		}
		password, err := generatePassword(length)
		if err != nil {
			fmt.Printf("Error: %s\n", err)
			return
		}
		fmt.Printf("Generated Password: %s\n", password)
		return
	}

	// HTTP server mode
	http.HandleFunc("/", handlePasswordRequest)

	fmt.Println("Starting server on :8080")
	http.ListenAndServe(":8080", nil)
}
