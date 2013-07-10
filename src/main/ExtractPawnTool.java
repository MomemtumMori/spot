package main;

import java.io.BufferedReader;
import java.io.FileReader;
import java.io.IOException;

import org.antlr.v4.runtime.*;
import org.antlr.v4.runtime.tree.*;

import parser.*;

public class ExtractPawnTool {
	public static void main(String[] args) throws Exception {
		ANTLRInputStream input = new ANTLRInputStream(getFileContent(args[0]).toString());
		// create a lexer that feeds off of input CharStream
		SPOTLexer lexer = new SPOTLexer(input);
		// create a buffer of tokens pulled from the lexer
		CommonTokenStream tokens = new CommonTokenStream(lexer);
		// create a parser that feeds off the tokens buffer
		SPOTParser parser = new SPOTParser(tokens);
		ParseTree tree = parser.compilationUnit(); // begin parsing at init rule
		ParseTreeWalker walker = new ParseTreeWalker(); // create standard
														// walker
		ExtractPawnListener extractor = new ExtractPawnListener(parser);
		walker.walk(extractor, tree); // initiate walk of tree with listener
		System.out.println(extractor.getOutput());
	}
	
	private static StringBuffer getFileContent(String path) throws IOException {
		StringBuffer sb = new StringBuffer();
		BufferedReader br = null;
 
		try { 
			String sCurrentLine; 
			br = new BufferedReader(new FileReader(path));
 
			while ((sCurrentLine = br.readLine()) != null) {
				sb.append(sCurrentLine);
				sb.append("\n");
			}
 
		} catch (IOException e) {
			throw e;
		} finally {
			try {
				if (br != null)
					br.close();
			} catch (IOException ex) {
				throw ex;
			}
		}
		
		return sb;
	}
}
