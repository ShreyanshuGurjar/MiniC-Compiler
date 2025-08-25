%{
    #include <bits/stdc++.h>
    #include <stdlib.h>
    #include <stdio.h>
    #include <string.h>
    using namespace std;
    void yyerror(const char* c);
    int yylex(void);
    extern char* yytext;
    extern int yylineno;
    int t_count = 1,param_count=1,l_count=1;
    map<string,int> vars;   // 1-> local, 2-> global, 0-> not defined
    int location=2;         // 1-> local, 2-> global
    vector<string> args,params;
    string exp_buff;
    string x86_buff;
    vector<string> x86_fun_code;
    int offset = 0;
    int params_offset = 4;
    map<string, int> params_address;
    map<string,int> local_address;
    map<string,string> local_type;
    map<string,string> global_type;
    map<string, string> fun_string_data;
    int flag = 0;

    char* create_t(){
        string s="t"+to_string(t_count);
        t_count++;
        return strdup(s.c_str());
    }

    class cond{
        public:
        string comp,sep;
        string comparator;
        cond *left, *right;
        string decl;
        // to calculate
        int tstate,fstate;

        cond(string c,string d, string e){
            comp=c;
            decl=d;
            comparator = e;
            sep.clear();
            left=NULL;
            right=NULL;
            tstate=-1;
            fstate=-1;
        }
        cond(cond *l, string s, cond *r){
            comp.clear();
            sep=s;
            left=l;
            right=r;
            tstate=-1;
            fstate=-1;
        }

        void set_state(int t,int f){
            tstate=t;
            fstate=f;
            if(sep.empty()){
                return;
            }
            if(sep=="!"){
                left->set_state(f,t);
                return;
            }
            if(sep=="||"){
                left->set_state(t,l_count++);
                right->set_state(t,f);
                return;
            }
            if(sep=="&&"){
                left->set_state(l_count++,f);
                right->set_state(t,f);
                return;
            }
            cout << "GADBAD\n";
            return;
        }

        string get_code(){
            if(sep.empty()){
                /*
                ti = comp
                if (ti) goto true
                goto false
                */
                //string code=decl + "t" + to_string(t_count) + " = " + comp + "\n"
                //    + "if (t" + to_string(t_count) + ") goto L" + to_string(tstate) + "\n"
                //    + "goto L" + to_string(fstate) + "\n";

                string code;
                if(comparator == ">"){
                    code = decl + "jg L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }
                else if(comparator == "<"){
                    code = decl + "jl L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }
                else if(comparator == ">="){
                    code = decl + "jge L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }
                else if(comparator == "<="){
                    code = decl + "jle L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }
                else if(comparator == "=="){
                    code = decl + "je L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }
                else if(comparator == "!="){
                    code = decl + "jne L" +to_string(tstate) + "\n"
                            + "jmp L" + to_string(fstate) + "\n";
                }

                t_count++;
                decl.clear();
                return code;
            }
            if(sep=="!"){
                string code=left->get_code();
                delete(left);
                return code;
            }
            if(sep=="||"){
                string code=left->get_code()
                    //+ "L" + to_string(left->fstate) + ":\n"
                    + "L" + to_string(left->fstate) + ":\n"
                    + right->get_code();
                delete(left);
                delete(right);
                return code;
            }
            if(sep=="&&"){
                string code=left->get_code()
                    //+ "L" + to_string(left->tstate) + ":\n"
                    + "L" + to_string(left->tstate) + ":\n"
                    + right->get_code();
                delete(left);
                delete(right);
                return code;
            }
            return "GADBAD\n";
        }
    };
%}

%token INT ELSE CHAR PWR RET OR NOT AND HEADER

%union{
    char* str;
    int val;
    int arr[2];
    char c;
    void* cond_ptr;
}

%token<str> VAR TEXT COMP SOME_CHAR
%token<val> CONST IF WHILE
%token<c> MD

%type<str> access_var exp unary_exp datatype
%type<val> arguments some_arguments parameters some_parameters
%type<arr> base_line
%type<cond_ptr> condition one_cond not_cond

%left OR
%left AND
%right NOT
%left '+' '-'
%left MD
%right PWR

%%

start: HEADER {cout << ".bss" << endl;}program;

program: 
        | function program 
        | declaration ';' program
        //| decl_assign ';' program;

function: datatype VAR '(' parameters ')' '{'{
    //cout << $2 << ":\n";
    exp_buff.clear();
    x86_buff.clear();
    offset=0;
    params_offset=4;
    x86_fun_code.clear();

    location=1;
    param_count=1;
    for(int i=params.size()-$4;i<params.size();i++){
        vars.insert({params[i],1});
        //cout << params[i] << " = " << "param" << param_count++ << "\n";
    }
    //x86_fun_code.push_back(string($2)+":");
    params.resize(params.size()-$4);
    param_count=1;
    } body '}'{

    if(flag == 0){cout << ".text\n";flag = 1;}
    cout<< ".globl " << $2 <<endl;
    cout<< $2 << ":" << endl;
    cout<< "pushl %ebp" << endl;
    cout<< "movl %esp, %ebp" <<endl;


    location=2;

    int vars_size = 0;

    map<string,int>::iterator itr=vars.begin();
    while(itr!=vars.end()){
        if(itr->second==1){
            vars.erase(itr++);
            vars_size++;
        }
        else{
            itr++;
        }
    }

    cout<< "subl $" << to_string(offset*(-1)) << ", %esp" << endl;

    for(int i=0;i<x86_fun_code.size();i++){
        cout << x86_fun_code[i] << endl;
    }
    x86_fun_code.clear();

    //cout << "\n";
};

datatype: INT {
            $$= strdup("int");
        }
        | CHAR{
            $$= strdup("char");
        }
;

parameters: 
        {$$=0;}| some_parameters{$$=$1;};
    
some_parameters:  parameter{$$=1;}
                | parameter ',' some_parameters{$$=1+$3;};

parameter:  datatype VAR{
                params.push_back(string($2));
                local_type[string($2)] = string($1);
                params_offset += 4;
                local_address[string($2)] = params_offset;

        }
        |   datatype VAR '[' optional_exp ']'{
                params.push_back(string($2));
                local_type[string($2)] = string($1);
                params_offset += 4;
                local_address[string($2)] = params_offset;
        };

optional_exp: | exp;

arguments:
        {$$=0;}| some_arguments{$$=$1;};

some_arguments:   one_arg{$$=1;}
                | one_arg ',' some_arguments{$$=1+$3;};

one_arg: exp{
            //exp_buff+="t" + to_string(t_count) + " = " + string($1) + "\n";
            offset -= 4;
            x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";
            x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
            local_address["t" + to_string(t_count)] = offset;

            string s="t";
            s+=to_string(t_count);
            t_count++;
            args.push_back(s);
        } | TEXT{
            //exp_buff+="t" + to_string(t_count) + " = " + string($1) + "\n";
            
            string temp = "fmt" + to_string(fun_string_data.size()+1);
            fun_string_data[temp] = string($1);

            offset -= 4;
            x86_buff += "movl $" + temp + ", %eax\n";
            x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
            local_address["t" + to_string(t_count)] = offset;

            string s="t";
            s+=to_string(t_count);
            t_count++;
            args.push_back(s);

};

exp:  exp '+' exp{
        //exp_buff+="t" + to_string(t_count) + " = " + string($1) + " + " + string($3) + "\n";
        offset -= 4;
        local_address["t" + to_string(t_count)] = offset;
        x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";
        x86_buff += "addl " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";
        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
        free($1);
        free($3);
        $$=create_t();
    } | exp '-' exp{
        //exp_buff+="t" + to_string(t_count) + " = " + string($1) + " - " + string($3) + "\n";
        offset -= 4;
        local_address["t" + to_string(t_count)] = offset;
        x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";
        x86_buff += "subl " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";
        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
        free($1);
        free($3);
        $$=create_t();
    } | exp MD exp{
        //exp_buff+="t" + to_string(t_count) + " = " + string($1) + " " + $2 + " " + string($3) + "\n";
        offset -= 4;
        local_address["t" + to_string(t_count)] = offset;
        x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";

        if($2 == '*') x86_buff += "imul " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";
        else if($2 == '/'){ x86_buff += "cdq\nidivl " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";}

        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
        free($1);
        free($3);
        $$=create_t();
    } | exp PWR exp{
        //exp_buff+="t" + to_string(t_count) + " = " + string($1) + " ** " + string($3) + "\n";
        //free($1);
        //free($3);
        //$$=create_t();
    } | unary_exp{$$=$1;}
      | '+' unary_exp{
        offset -= 4;
        local_address["t" + to_string(t_count)] = offset;
        
        x86_buff += "movl $0, %eax\n";
        x86_buff += "addl " + to_string(local_address[string($2)]) + "(%ebp), %eax\n";
        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
        free($2);
        $$=create_t();
        //exp_buff+="t" + to_string(t_count) + " = " + " +" + string($2) + "\n";
        //free($2);
        //$$=create_t();
    } | '-' unary_exp{
        //exp_buff+="t" + to_string(t_count) + " = " + " -" + string($2) + "\n";

        offset -= 4;
        local_address["t" + to_string(t_count)] = offset;
        
        x86_buff += "movl $0, %eax\n";
        x86_buff += "subl " + to_string(local_address[string($2)]) + "(%ebp), %eax\n";
        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
        free($2);
        $$=create_t();
    };

unary_exp:   CONST{
                //exp_buff+="t" + to_string(t_count) + " = " + to_string($1) + "\n";
                offset -= 4;
                local_address["t" + to_string(t_count)] = offset;
                x86_buff += "movl $" + to_string($1) + ", " + to_string(offset) + "(%ebp)\n";
                $$=create_t();
            } | SOME_CHAR{
                //exp_buff+="t" + to_string(t_count) + " = " + string($1) + "\n";
                offset -= 4;
                local_address["t" + to_string(t_count)] = offset;
                x86_buff += "movl $" + string($1) + ", " + to_string(offset) + "(%ebp)\n";
                $$=create_t();
            } | access_var{
                //exp_buff+="t" + to_string(t_count) + " = " + string($1) + "\n";
                offset -= 4;
                local_address["t" + to_string(t_count)] = offset;

                //for global array, give leal arr to some temp
                // for local array that is paramter, give movl address(%ebp) to temp
                // for local array variable, give leal address(%ebp) to temp  leal (some neg number)(%ebp), temp address 


                if(global_type[string($1)] == "char"){
                    if(vars[string($1)] == 2){
                        x86_buff += "leal " + string($1) + ", %eax\n";
                        x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
                    }
                    else{
                        if(local_address[string($1)] <= 0){
                            x86_buff += "movl %ebp, %eax\n";
                            x86_buff += "subl " + to_string(-1*local_address[string($1)]) + "(%ebp), %eax\n";
                            x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
                        }
                        else{
                            x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";
                            x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
                         }
                    }
                }
                else{
                    if(vars[string($1)] == 2)
                    x86_buff += "movl " + string($1) + ", %eax\n";
                    else 
                    x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";

                    x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";
                            }
                free($1);
                $$=create_t();
            } | VAR '(' arguments ')'{
		int cnt = 0;
		int number = $3;
                for(int i=args.size()-1;cnt < number;i--){
                    //exp_buff+="param" + to_string(param_count) + " = " + args[i] + "\n";
                    x86_buff += "pushl " + to_string(local_address[args[i]]) + "(%ebp)\n";
                    param_count++;
                    cnt++;
                }
                //exp_buff+="call " + string($1) + "\n";
                x86_buff += "call " + string($1) + "\n";
                free($1);
                args.resize(args.size()-$3);
                param_count=1;
                //exp_buff+=string($$) + " = retval\n";
                x86_buff += "addl $" + to_string(4*$3) + ", %esp\n";

                offset -= 4;

                local_address["t" + to_string(t_count)] = offset;
                x86_buff += "movl %eax, " + to_string(offset) + "(%ebp)\n";

                $$ = create_t();
                // $$=strdup("retval");
            } | '(' exp ')'{$$=$2;};

access_var: VAR{
            if(vars.find($1)==vars.end()){
                string s="undefined variable " + string($1);
                yyerror(s.c_str());
            }

            $$=strdup($1);
            
        } | VAR '[' exp ']'{
            if(vars.find($1)==vars.end()){
                string s="undefined variable " + string($1);
                yyerror(s.c_str());
            }
            string s=string($1) + "[" + string($3) + "]";
            $$=strdup($1);
};

condition: one_cond{
            $$=$1;
         }| condition OR condition{
            $$=new cond((cond *)$1,"||",(cond *)$3);
         }| condition AND condition{
            $$=new cond((cond *)$1,"&&",(cond *)$3);
};

one_cond: exp COMP exp{
            x86_buff += "movl " + to_string(local_address[string($1)]) + "(%ebp), %eax\n";
            x86_buff += "cmpl " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";
            $$=new cond(string($1)+string($2)+string($3),x86_buff, string($2));
            //exp_buff.clear();
            x86_buff.clear();
        }| not_cond{
            $$=$1;
};

not_cond: '(' condition ')'{
            $$=$2;
          }| NOT not_cond{
            $$=new cond((cond *)$2,"!",NULL);
};

body: 
    | line body
    | '{' body '}' body;

line: exp ';'{
        //cout << exp_buff; exp_buff.clear();
        x86_fun_code.push_back(x86_buff); x86_buff.clear();
    }
    | declaration ';'
    //| decl_assign ';'
    | assignment ';'{
        //cout << exp_buff; exp_buff.clear();
        x86_fun_code.push_back(x86_buff); x86_buff.clear();
    }
    | if_statement
    | while_loop
    | RET exp ';'{

        //cout << exp_buff; exp_buff.clear(); cout << "retval = " << $2 << "\n"; cout << "return\n";
        x86_fun_code.push_back(x86_buff);
        x86_buff.clear();
        //x86_fun_code.push_back(exp_buff);
        x86_fun_code.push_back("movl " + to_string(local_address[string($2)]) + "(%ebp), %eax");
        x86_fun_code.push_back("leave");
        x86_fun_code.push_back("ret");
    }
//    | RET condition ';'{
//        cond* ptr=((cond*)$2);
//        int t_state=l_count++,f_state=l_count++;
//        ptr->set_state(t_state,f_state);
//        cout << ptr->get_code();
//        cout << "L" << t_state << ":\n";
//        char *t= create_t();
//        cout << t << " = 1\n";
//        cout << "retval = " << t << "\nreturn\n";
//        cout << "L" << f_state << ":\n";
//        t= create_t();
//        cout << t << " = 0\n";
//        cout << "retval = " << t << "\nreturn\n";
//}
;
    
one_or_more_lines: line | '{' body '}';

if_statement: base_line {
                //cout << "L" << $1[0] << ":\n";
                x86_fun_code.push_back("L" + to_string($1[0]) + ":");
            }| base_line ELSE{
                l_count++;
                //cout << "goto L" << $1[1] << "\n";
                //cout << "L" << $1[0] << ":\n";
                x86_fun_code.push_back("jmp L" + to_string($1[1]));
                x86_fun_code.push_back("L" + to_string($1[0]) + ":");
} one_or_more_lines{
                //cout << "L" << $1[1] << ":\n";
                x86_fun_code.push_back("L" + to_string($1[1]) + ":");
};

base_line: IF '(' condition ')'{
    l_count++;
    ((cond*)$3)->set_state($1,$1+1);
    //cout << ((cond*)$3)->get_code();
    x86_fun_code.push_back(((cond*)$3)->get_code());
    delete((cond*)$3);
    //cout << "L" << $1 << ":\n";
    x86_fun_code.push_back("L" + to_string($1) + ":");
} one_or_more_lines{
    $$[0]=$1+1;
    $$[1]=l_count;
};


while_loop: WHILE '(' condition ')'{
    l_count+=2;
    ((cond*)$3)->set_state($1+1,$1+2);
    //cout << "L" << $1 << ":\n";
    x86_fun_code.push_back("L" + to_string($1) + ":");
    //cout << ((cond*)$3)->get_code();
    x86_fun_code.push_back(((cond*)$3)->get_code());
    delete((cond*)$3);
    //cout << "L" << $1+1 << ":\n";
    x86_fun_code.push_back("L" + to_string($1+1) + ":");
}one_or_more_lines{
    //cout << "goto L" << $1 << "\n";
    x86_fun_code.push_back("jmp L" + to_string($1));
    //cout << "L" << $1+2 << ":\n";
    x86_fun_code.push_back("L" + to_string($1+2) + ":");
};

//declaration: simple_declaration
//            | declaration ',' make_var;

//simple_declaration: datatype make_var;

declaration: datatype VAR{
        if(location==2){ 
            //cout << "global " << $1 << "\n";
            cout<<$2<<": .space 4"<<endl;
            global_type[string($2)] = string($1);
        }        
        else{
            local_type[string($2)] = string($1);
            offset -= 4;
            local_address[string($2)] = offset;
        }
        vars.insert({string($2),location});
    }| datatype VAR '[' exp ']'{
        //cout << exp_buff;
        //exp_buff.clear();

        x86_fun_code.push_back(x86_buff);
        x86_buff.clear();

        //if(location==2) cout << "global " << $1 << "[" << $3 << "]\n";
        
        if(location==2){ 
            //cout << "global " << $1 << "\n";
            cout<<$2<<": .space "<<$4<<endl;
            global_type[string($2)] = string($1);
        }        
        else{
            local_type[string($2)] = string($1);
            string temp = string($4);
            temp = temp.substr(1, temp.size()-1);
            offset -= stoi(temp);
            x86_fun_code.push_back("subl $" + string($4) + ", %esp #local " + string($2) + "[" + $4 + "] at " + to_string(offset));
            local_address[string($2)] = offset;
        }
        vars.insert({string($2),location});
};

assignment: access_var '=' exp{
    //exp_buff+=string($1) + " = " + string($3) + "\n";
    x86_buff += "movl " + to_string(local_address[string($3)]) + "(%ebp), %eax\n";
    if(vars[string($1)] == 2)
    x86_buff += "movl %eax, " + string($1) + "\n";
    else
    x86_buff += "movl %eax, " + to_string(local_address[string($1)]) + "(%ebp)\n";
}
    | access_var '[' exp ']' '=' SOME_CHAR {

        string temp = string($6);
        temp = temp.substr(1, temp.size()-2);
        if(vars[string($6)] == 2){
            x86_fun_code.push_back("movl " + to_string(local_address[string($3)]) + "(%ebp), %ecx");
            x86_fun_code.push_back("leal " + string($1) + ", %ebx");
            x86_fun_code.push_back("addl %ebx, %ecx");
            if(temp != "\\0")x86_fun_code.push_back("movb $'" + temp + "', (%ecx)");
            else x86_fun_code.push_back("movb $0, (%ecx)");
        }
        else{
            if(local_address[string($1)] <= 0){
                x86_fun_code.push_back("movl " + to_string(local_address[$3]) + "(%ebp), %ecx");
                x86_fun_code.push_back("addl %ebp, %ecx");
                if(temp != "\\0")x86_fun_code.push_back("movb $'" + temp + "', " + to_string(local_address[string($1)]) + "(%ecx)");
                else x86_fun_code.push_back("movb $0, " + to_string(local_address[string($1)]) + "(%ecx)");
            }
            else{
                x86_fun_code.push_back("movl " + to_string(local_address[$3]) + "(%ebp), %ecx");
                x86_fun_code.push_back("addl " + to_string(local_address[string($1)]) + "(%ebp), %ecx");
                if(temp != "\\0")x86_fun_code.push_back("movb $'" + temp + "', 0(%ecx)");
                else x86_fun_code.push_back("movb $0, 0(%ecx)");
            }
        }
    } 

    | access_var '[' exp ']' '=' access_var '[' exp ']'{
            if(vars[string($6)] == 2){
            x86_fun_code.push_back("movl " + to_string(local_address[$8]) + "(%ebp), %ecx");
            x86_fun_code.push_back("leal " + string($6) + ", %ebx");
            x86_fun_code.push_back("addl %ebx, %ecx");
            x86_fun_code.push_back("movb (%ecx), %al"); 
        }
            else{
                if(local_address[string($6)] > 0){
                    x86_fun_code.push_back("movl " + to_string(local_address[$8]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("addl " + to_string(local_address[string($6)]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("movb (%ecx), %al"); 
                }
                else{
                    x86_fun_code.push_back("movl " + to_string(local_address[$8]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("addl %ebp, %ecx");
                    x86_fun_code.push_back("movb " + to_string(local_address[string($6)]) + "(%ecx), %al");
                }
            }

            if(vars[string($1)] == 2){
                x86_fun_code.push_back("movl " + to_string(local_address[$3]) + "(%ebp), %ecx");
                x86_fun_code.push_back("leal " + string($1) + ", %ebx");
                x86_fun_code.push_back("addl %ebx, %ecx");
                x86_fun_code.push_back("movb %al, (%ecx)"); 
            }
            else{
                if(local_address[string($1)] > 0){
                    x86_fun_code.push_back("movl " + to_string(local_address[$3]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("addl " + to_string(local_address[string($1)]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("movb %al, (%ecx)"); 
                }
                else{
                    x86_fun_code.push_back("movl " + to_string(local_address[$3]) + "(%ebp), %ecx");
                    x86_fun_code.push_back("addl %ebp, %ecx");
                    x86_fun_code.push_back("movb %al, " + to_string(local_address[string($1)]) + "(%ecx)");
                }
            }
        }

;

//decl_assign: datatype VAR '=' exp{
//    cout << exp_buff;
//    exp_buff.clear();
//    if(location==2) cout << "global " << $2 << "\n";
//    vars.insert({string($2),location});
//    cout << $2 << " = " << $4 << "\n";
//};

%%

void yyerror(const char *c){
    cout << c << "\n";
    exit(1);
}

int main(void){
    yyparse();

    cout << ".data" << endl;
    for(auto x : fun_string_data){
        cout << x.first << ": .asciz " << x.second << endl;
    }

    return 0;
}
