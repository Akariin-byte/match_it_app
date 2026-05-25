package cache

import "errors"

var ErrNotFound = errors.New("cache: not found")

func IsNotFound(err error) bool {
	return errors.Is(err, ErrNotFound)
}
