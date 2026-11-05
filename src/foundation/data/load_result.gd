class_name LoadResult extends RefCounted
## The result of a catalogue load: either a READY catalogue or every error.

## True when the catalogue loaded and validated with no error.
var ok: bool = false
var errors: Array[ValidationError] = []
## READY when `ok`; null otherwise.
var catalogue: Catalogue = null


## A successful result holding the READY catalogue.
static func success(p_catalogue: Catalogue) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	result.ok = true
	result.catalogue = p_catalogue
	return result


## A failed result holding every error and no catalogue.
static func failure(p_errors: Array[ValidationError]) -> LoadResult:
	var result: LoadResult = LoadResult.new()
	result.ok = false
	result.errors.assign(p_errors)
	return result
