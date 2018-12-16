%{
namespace ast{
class node;
}
using namespace ast;
#define YYSTYPE node*
#include "../ast.h"
using namespace ast;

extern char* yytext;
void yyerror(const char *s);
int yylex(void);

translation_unit *ast_root;

%}
 
%token IDENTIFIER CONSTANT STRING_LITERAL
%token PTR_OP INC_OP DEC_OP LEFT_OP RIGHT_OP LE_OP GE_OP EQ_OP NE_OP
%token AND_OP OR_OP MUL_ASSIGN DIV_ASSIGN MOD_ASSIGN ADD_ASSIGN
%token SUB_ASSIGN LEFT_ASSIGN RIGHT_ASSIGN AND_ASSIGN
%token XOR_ASSIGN OR_ASSIGN TYPE_NAME
%token VOID UINT8 UINT16 UINT32 UINT64 INT8 INT16 INT32 INT64 FP32 FP64
%token IF ELSE FOR
%token DEF

%start translation_unit
%%


/* -------------------------- */
/*         Types              */
/* -------------------------- */

type_specifier
	: VOID
	| UINT8 | UINT16 | UINT32 | UINT64
	| INT8 | INT16 | INT32 | INT64
	| FP32 | FP64
	;

pointer
	: '*' { $$ = new pointer_declarator(1); }
	| '*' pointer { $$ = ((pointer_declarator*)$1)->inc(); }
	
abstract_declarator
	: pointer { $$ = $1; }
	| direct_abstract_declarator { $$ = $1; }
	| pointer direct_abstract_declarator { $$ = new compound_declarator($1, $2); }
	;

direct_abstract_declarator
	: '[' constant_list ']' { $$ = new tile_declarator($1); }

constant : 
	CONSTANT { $$ = new constant(atoi(yytext)); }
	;
	
constant_list
	: constant  { $$ = new list<constant*>((constant*)$1); }
	| constant_list ',' constant { $$ = append_ptr_list<constant>($1, $2); }
	;

type_name
	: type_specifier { $$ = new type((yytokentype)(size_t)$1, nullptr); }
	| type_specifier abstract_declarator { $$ = new type((yytokentype)(size_t)$1, $2); }
	;

/* -------------------------- */
/*         Expressions        */
/* -------------------------- */

identifier
	: IDENTIFIER { $$ = new identifier(yytext); }
	;
	
primary_expression
	: identifier  { $$ = $1; }
	| constant { $$ = $1; }
	| STRING_LITERAL { $$ = new string_literal(yytext); }
	| '(' unary_expression ')' { $$ = $1; }
	;

unary_expression
	: primary_expression { $$ = $1; }
	| INC_OP unary_expression { $$ = new unary_operator(INC_OP, $2); }
	| DEC_OP unary_expression { $$ = new unary_operator(DEC_OP, $2); }
	| unary_operator cast_expression { $$ = new unary_operator((yytokentype)(size_t)$1, $2); }
	;

unary_operator
	: '&'
	| '*'
	| '+'
	| '-'
	| '~'
	| '!'
	;

cast_expression
	: unary_expression { $$ = $1; }
	| '(' type_name ')' cast_expression { $$ = new cast_operator((yytokentype)(size_t)$1, $2); }
	;

multiplicative_expression
	: cast_expression { $$ = $1; }
	| multiplicative_expression '*' cast_expression { $$ = new binary_operator('*', $1, $3); }
	| multiplicative_expression '/' cast_expression { $$ = new binary_operator('/', $1, $3); }
	| multiplicative_expression '%' cast_expression { $$ = new binary_operator('%', $1, $3); }
	;

additive_expression
	: multiplicative_expression { $$ = $1; }
	| additive_expression '+' multiplicative_expression { $$ = new binary_operator('+', $1, $3); }
	| additive_expression '-' multiplicative_expression { $$ = new binary_operator('-', $1, $3); }
	;

shift_expression
	: additive_expression { $$ = $1; }
	| shift_expression LEFT_OP additive_expression { $$ = new binary_operator(LEFT_OP, $1, $3); }
	| shift_expression RIGHT_OP additive_expression { $$ = new binary_operator(RIGHT_OP, $1, $3); }
	;

relational_expression
	: shift_expression { $$ = $1; }
	| relational_expression '<' shift_expression { $$ = new binary_operator('<', $1, $3); }
	| relational_expression '>' shift_expression { $$ = new binary_operator('>', $1, $3); }
	| relational_expression LE_OP shift_expression { $$ = new binary_operator(LE_OP, $1, $3); }
	| relational_expression GE_OP shift_expression { $$ = new binary_operator(GE_OP, $1, $3); }
	;

equality_expression
	: relational_expression { $$ = $1; }
	| equality_expression EQ_OP relational_expression { $$ = new binary_operator(EQ_OP, $1, $3); }
	| equality_expression NE_OP relational_expression { $$ = new binary_operator(NE_OP, $1, $3); }
	;

and_expression
	: equality_expression { $$ = $1; }
	| and_expression '&' equality_expression { $$ = new binary_operator('&', $1, $3); }
	;

exclusive_or_expression
	: and_expression { $$ = $1; }
	| exclusive_or_expression '^' and_expression { $$ = new binary_operator('^', $1, $3); }
	;

inclusive_or_expression
	: exclusive_or_expression { $$ = $1; }
	| inclusive_or_expression '|' exclusive_or_expression { $$ = new binary_operator('|', $1, $3); }
	;

logical_and_expression
	: inclusive_or_expression { $$ = $1; }
	| logical_and_expression AND_OP inclusive_or_expression { $$ = new binary_operator(AND_OP, $1, $3); }
	;

logical_or_expression
	: logical_and_expression { $$ = $1; }
	| logical_or_expression OR_OP logical_and_expression { $$ = new binary_operator(OR_OP, $1, $3); }
	;

conditional_expression
	: logical_or_expression { $$ = $1; }
	| logical_or_expression '?' conditional_expression ':' conditional_expression { $$ = new conditional_expression($1, $2, $3); }
	;

assignment_operator
	: '='
	| MUL_ASSIGN
	| DIV_ASSIGN
	| MOD_ASSIGN
	| ADD_ASSIGN
	| SUB_ASSIGN
	| LEFT_ASSIGN
	| RIGHT_ASSIGN
	| AND_ASSIGN
	| XOR_ASSIGN
	| OR_ASSIGN
	;


assignment_expression
	: conditional_expression { $$ = $1; }
	| unary_expression assignment_operator assignment_expression { $$ = new assignment_expression($1, (yytokentype)(size_t)$2, $3); }
	;

expression
	: assignment_expression { $$ = $1; }
	;

/* -------------------------- */
/*         Statements         */
/* -------------------------- */

statement
	: compound_statement { $$ = $1; }
	| expression_statement { $$ = $1; }
	| selection_statement { $$ = $1; }
	| iteration_statement { $$ = $1; }
	;

compound_statement
	: '{' '}' { $$ = new compound_statement(); }
	| '{' statement_list '}' { $$ = $1; }
	;

statement_list
	: statement { $$ = new compound_statement($1); }
	| statement_list statement { $$ = append_ptr_list<compound_statement>($1, $2); }
	;
	
expression_statement
	: ';' { $$ = new no_op(); }
	| expression ';' { $$ = $1; }
	;

selection_statement
	: IF '(' expression ')' statement { $$ = new selection_statement($1, $2); }
	| IF '(' expression ')' statement ELSE statement { $$ = new selection_statement($1, $2, $3); }
	;

iteration_statement
	: FOR '(' expression_statement expression_statement ')' statement { $$ = new iteration_statement($1, $2, NULL, $3); }
	| FOR '(' expression_statement expression_statement expression ')' statement { $$ = new iteration_statement($1, $2, $3, $3); }
	;


/* -------------------------- */
/*         Declarator         */
/* -------------------------- */


direct_declarator
	: identifier { $$ = $1; }
	| direct_declarator '[' constant_list ']' { $$ = new tile_declarator($2); }
	| direct_declarator '(' parameter_list ')' { $$ = new function_declarator($2); }
	| direct_declarator '(' identifier_list ')' { $$ = new function_declarator($2); }
	| direct_declarator '(' ')' { $$ = new function_declarator(nullptr); }
	;
	
identifier_list
	: identifier { $$ = new list<identifier*>((identifier*)$1); }
	| identifier_list ',' identifier { $$ = append_ptr_list<identifier>($1, $2); }
	;

parameter_list
	: parameter_declaration { $$ = new list<parameter*>((parameter*)$1); }
	| parameter_list ',' parameter_declaration { $$ = append_ptr_list<parameter>($1, $2); }
	;

parameter_declaration
	: declaration_specifiers declarator { $$ = new parameter((yytokentype)(size_t)$1, $2); }
	| declaration_specifiers abstract_declarator { $$ = new parameter((yytokentype)(size_t)$1, $2); }
	| declaration_specifiers { $$ = new parameter((yytokentype)(size_t)$1, nullptr); }
	;


declaration_specifiers
	: type_specifier { $$ = $1; }
	;

init_declarator_list
	: init_declarator { $$ = new list<init_declarator*>((init_declarator*)$1); }
	| init_declarator_list ',' init_declarator { $$ = append_ptr_list<init_declarator>($1, $2); }
	;

declaration
	: declaration_specifiers ';' { $$ = new declaration($1, nullptr); }
	| declaration_specifiers init_declarator_list ';' { $$ = new declaration($1, $2); }
	;
	
declarator
	: pointer direct_declarator { $$ = new compound_declarator($1, $2); }
	| direct_declarator { $$ = $1; }
	;

initializer
	: assignment_expression { $$ = $1; }
	| '{' constant '}' { $$ = $1; }
	;
	
init_declarator
	: declarator { $$ = new init_declarator($1, nullptr); }
	| declarator '=' initializer { $$ = new init_declarator($1, $2); }
	;

/* -------------------------- */
/*      Translation Unit 	  */
/* -------------------------- */

translation_unit
	: external_declaration { $$ = new translation_unit($1); }
	| translation_unit external_declaration { $$ = ((translation_unit*)($1))->add($2); }
	;
	
external_declaration
	: function_definition { $$ = $1; }
	| declaration { $$ = $1; }
	;
	
function_definition
	: declarator compound_statement { $$ = new function_definition($1, $2); }
	;

