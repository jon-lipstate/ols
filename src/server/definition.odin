package server

import "core:odin/parser"
import "core:odin/ast"
import "core:odin/tokenizer"
import "core:fmt"
import "core:log"
import "core:strings"
import path "core:path/slashpath"
import "core:mem"
import "core:strconv"
import "core:path/filepath"
import "core:sort"
import "core:slice"
import "core:os"

import "shared:common"

get_definition_location :: proc(
	document: ^Document,
	position: common.Position,
) -> (
	[]common.Location,
	bool,
) {
	locations := make([dynamic]common.Location, context.temp_allocator)

	location: common.Location

	ast_context := make_ast_context(
		document.ast,
		document.imports,
		document.package_name,
		document.uri.uri,
		document.fullpath,
	)

	uri: string

	position_context, ok := get_document_position_context(
		document,
		position,
		.Definition,
	)

	if !ok {
		log.warn("Failed to get position context")
		return {}, false
	}

	get_globals(document.ast, &ast_context)

	if position_context.function != nil {
		get_locals(
			document.ast,
			position_context.function,
			&ast_context,
			&position_context,
		)
	}

	if position_context.selector_expr != nil {
		//if the base selector is the client wants to go to.
		if base, ok := position_context.selector.derived.(^ast.Ident);
		   ok && position_context.identifier != nil {
			ident := position_context.identifier.derived.(^ast.Ident)

			if position_in_node(base, position_context.position) {
				if resolved, ok := resolve_location_identifier(
					   &ast_context,
					   ident^,
				   ); ok {
					location.range = resolved.range

					if resolved.uri == "" {
						location.uri = document.uri.uri
					} else {
						location.uri = resolved.uri
					}

					append(&locations, location)

					return locations[:], true
				} else {
					return {}, false
				}
			}
		}

		if resolved, ok := resolve_location_selector(
			   &ast_context,
			   position_context.selector_expr,
		   ); ok {
			location.range = resolved.range
			uri = resolved.uri
		}
	} else if position_context.identifier != nil {
		if resolved, ok := resolve_location_identifier(
			   &ast_context,
			   position_context.identifier.derived.(^ast.Ident)^,
		   ); ok {
			location.range = resolved.range
			uri = resolved.uri
		} else {
			return {}, false
		}
	} else {
		return {}, false
	}

	//if the symbol is generated by the ast we don't set the uri.
	if uri == "" {
		location.uri = document.uri.uri
	} else {
		location.uri = uri
	}

	append(&locations, location)

	return locations[:], true
}
