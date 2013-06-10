package gr.agroknow.metadata.transformer.versita2agrif;

import gr.agroknow.metadata.agrif.Agrif;
import gr.agroknow.metadata.agrif.Citation;
import gr.agroknow.metadata.agrif.ControlledBlock;
import gr.agroknow.metadata.agrif.Creator;
import gr.agroknow.metadata.agrif.Expression;
import gr.agroknow.metadata.agrif.Item;
import gr.agroknow.metadata.agrif.LanguageBlock;
import gr.agroknow.metadata.agrif.Manifestation;
import gr.agroknow.metadata.agrif.Relation;
import gr.agroknow.metadata.agrif.Rights;
import gr.agroknow.metadata.agrif.Publisher;

import gr.agroknow.metadata.transformer.ParamManager;

import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.List;
import java.util.ArrayList;

import net.zettadata.generator.tools.Toolbox;
import net.zettadata.generator.tools.ToolboxException;

%%
%class VERSITA2AGRIF
%standalone
%unicode

%{
	// AGRIF
	private List<Agrif> agrifs ;
	private Agrif agrif ;
	private Citation citation ;
	private ControlledBlock cblock ;
	private Creator creator ;
	private Expression expression ;
	private LanguageBlock lblock ;
	private Rights rights ;
	
	// TMP
	private StringBuilder tmp ;
	private String language ;
	private String creatorName ;
	private String day ;
	private String month ;
	private String year ;
	private List<Publisher> publishers = new ArrayList<Publisher>() ;
	private boolean publisherProcessed = false ;
	private String citationNumber = "" ;
	private String citationChronology = "" ;
	
	public List<Agrif> getAgrifs()
	{
		return agrifs ;
	}
	
	private void init()
	{
		agrif = new Agrif() ;
		agrif.setCreationDate( utcNow()  ) ;
		agrif.setSet( ParamManager.getInstance().getSet() ) ;
		cblock = new ControlledBlock() ;
		cblock.setType( "dcterms", "journal article" ) ;
		expression = new Expression() ;
		// expression.setLanguage( "en" ) ;
		lblock = new LanguageBlock() ;
	}
		
	private String utcNow() 
	{
		Calendar cal = Calendar.getInstance() ;
		SimpleDateFormat sdf = new SimpleDateFormat( "yyyy-MM-dd" ) ;
		return sdf.format(cal.getTime()) ;
	}
	
	private String extract( String element )
	{	
		return element.substring(element.indexOf(">") + 1 , element.indexOf("</") ) ;
	}
	
%}

%state AGRIF
%state CITATION
%state ARTICLE
%state TITLE
%state CREATOR
%state DATE
%state ABSTRACT

%%

<YYINITIAL>
{	
	
	"<article>"
	{
		agrifs = new ArrayList<Agrif>() ;
		init() ;
		yybegin( AGRIF ) ;
	}
}

<AGRIF>
{
	"</article>"
	{
		if ( !publishers.isEmpty() && !publisherProcessed )
		{
			for ( Publisher publisher: publishers )
			{
				expression.setPublisher( publisher ) ;
			}
		}
		agrif.setExpression( expression ) ;
		agrif.setLanguageBlocks( lblock ) ;
		agrif.setControlled( cblock ) ;
		agrifs.add( agrif ) ;
		yybegin( YYINITIAL ) ;
	}
	
	"<journal-meta>"
	{
		yybegin( CITATION ) ;
		citation = new Citation() ;
	}
	
	"<article-meta>"
	{
		yybegin( ARTICLE ) ;
	}
	
}

<ARTICLE>
{
	"</article-meta>"
	{
		yybegin( AGRIF ) ;
		if ( !"".equals( citationNumber ) )
		{
			citation.setCitationNumber( citationNumber ) ;
		}
		if ( !"".equals( citationChronology ) )
		{
			citation.setCitationChronology( citationChronology ) ;
		}
		expression.setCitation( citation ) ;
		
	}

	"<article-id pub-id-type=\"doi\">".+"</article-id>"
	{
		String doi = extract( yytext() ) ;
		Item item = new Item() ;
		item.setDigitalItem( "http://dx.doi.org/" + doi.trim() ) ;
		Manifestation manifestation = new Manifestation() ;
		manifestation.setItem( item ) ;
		manifestation.setIdentifier( "doi", doi ) ;
		manifestation.setManifestationType( "landingPage" ) ;
		manifestation.setFormat( "text/html" ) ;
		expression.setManifestation( manifestation ) ;
	}
	
	"<article-title>"
	{
		tmp = new StringBuilder() ;
		yybegin( TITLE ) ;
	}
	
	"<contrib contrib-type=\"author\" corresp=\"yes\">"|"<contrib contrib-type=\"author\">"
	{
		yybegin( CREATOR ) ;
		creatorName = "" ;
	}
	
	"<pub-date pub-type=\"epub\">"
	{
		yybegin( DATE ) ;
		day = null ;
		month = null ;
		year = null ;
	}
	
	"<volume>".+"</volume>"
	{
		citationNumber = citationNumber + extract( yytext() ) ;
	}
	
	"<issue>".+"</issue>"
	{
		citationNumber = citationNumber + "(" + extract( yytext() ) + ")" ;
	}
	
	"<fpage>".+"</fpage>"
	{
		citationChronology = "pages " + extract( yytext() ) ;
	}
	
	"<lpage>".+"</lpage>"
	{
		citationChronology = citationChronology + "-" + extract( yytext() ) ;
	}
	
	"<license-p>".+"</license-p>"
	{
		String text = extract( yytext() ) ;
		language = ParamManager.getInstance().getLanguageFor( text ) ;
		rights = new Rights() ;
		rights.setRightsStatement( language, text ) ;
		agrif.setRights( rights ) ;
	}
	
	"<abstract>"
	{
		tmp = new StringBuilder() ;
		yybegin( ABSTRACT ) ;
	}
	
	"<kwd>".+"</kwd>"
	{
		String text = extract( yytext() ) ;
		language = ParamManager.getInstance().getLanguageFor( text ) ;
		lblock.setKeyword( language, text ) ;
	}
}

<ABSTRACT>
{
	"</abstract>"
	{
		String text = tmp.toString().trim() ;
		language = ParamManager.getInstance().getLanguageFor( text ) ;
		lblock.setAbstract( language, text ) ;
		yybegin( ARTICLE ) ;
	}
	
	"<title>Abstract</title>" {}
	"<p>"|"</p>" {} 
	
	\r|\t {}
	
	.
	{
		tmp.append( yytext() ) ;
	}
	
	\n
	{
		tmp.append( " " ) ;
	}
}

<DATE>
{
	"</pub-date>"
	{
		yybegin( ARTICLE ) ;
		String date = null ;
		if ( year != null )
		{
			date = year ;
			if ( month != null )
			{
				date = date + "-" + month ;
				if ( day != null )
				{
					date = date + "-" + day ;
				}
			}
		}
		if ( date != null )
		{
			publisherProcessed = true ;
			if ( publishers.isEmpty() )
			{
				Publisher publisher = new Publisher() ;
				publisher.setDate( date ) ;
				expression.setPublisher( publisher ) ;
			}
			else
			{
				for ( Publisher publisher: publishers )
				{
					publisher.setDate( date ) ;
					expression.setPublisher( publisher ) ;
				}
			}  
		}
	}
	
	"<day>".+"</day>"
	{
		day = extract( yytext() ) ;	
	}
	
	"<month>".+"</month>"
	{
		month = extract( yytext() ) ;
	}
	
	"<year>".+"</year>"
	{
		year = extract( yytext() ) ;
	}
}

<CREATOR>
{
	"</contrib>"
	{
		if ( !"".equals( creatorName ) )
		{
			creator = new Creator() ;
			creator.setType( "person" ) ;
			creator.setName( creatorName ) ;
			agrif.setCreator( creator ) ;
		}
		yybegin( ARTICLE ) ;
	}
	
	"<surname>".+"</surname>"
	{
		if ( "".equals( creatorName ) )
		{
			creatorName = extract( yytext() ).trim() ;
		}
		else
		{
			creatorName = creatorName + " " + extract( yytext() ).trim() ;
		}
	}
	
	"<given-names>".+"</given-names>"
	{
		if ( "".equals( creatorName ) )
		{
			creatorName = extract( yytext() ).trim() ;
		}
		else
		{
			creatorName = creatorName + ", " + extract( yytext() ).trim() ;
		}
	}
}

<TITLE>
{
	"</article-title>"
	{
		String text = tmp.toString().trim() ;
		language = ParamManager.getInstance().getLanguageFor( text ) ;
		lblock.setTitle( language, text ) ;
		yybegin( ARTICLE ) ;
	}
	
	\r|\t {}
	
	.
	{
		tmp.append( yytext() ) ;
	}
	
	\n
	{
		tmp.append( " " ) ;
	}
}

<CITATION>
{
	"<abbrev-journal-title abbrev-type=\"full\">".+"</abbrev-journal-title>"
	{
		citation.setTitle( extract( yytext() ) ) ;
	}
	
	"<issn pub-type=\"epub\">".+"</issn>"
	{
		citation.setIdentifier( "issn", extract( yytext() ) ) ;
	}

	"</journal-meta>"
	{
		yybegin( AGRIF ) ;
		// expression.setCitation( citation ) ;
	}
	
	"<publisher-name>".+"</publisher-name>"
	{
		Publisher publisher = new Publisher() ;
		publisher.setName( extract( yytext() ) ) ;
		publishers.add( publisher ) ;
	}
	
}

/* error fallback */
.|\n 
{
	//throw new Error("Illegal character <"+ yytext()+">") ;
}
