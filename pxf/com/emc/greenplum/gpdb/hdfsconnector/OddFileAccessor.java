package com.emc.greenplum.gpdb.hdfsconnector;

import java.io.DataInput;
import java.io.DataInputStream;
import java.io.InputStream;
import java.io.IOException;
import java.net.URI;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.FSDataInputStream;
import org.apache.hadoop.fs.FileSystem;
import org.apache.hadoop.fs.Path;

/*
 * Base class for inforcing the complete access of a file in one accessor. Since we  are not accessing the
 * file using the splittable API, but instead are using the "simple" stream API, it means that
 * we cannot fetch different parts (splits) of the file in different segment. Instead each file access
 * brings the complete file. And, if several segments would access the same file, then each one will return the whole
 * file and we will observe in the query result, each record appearing number_of_segments times. To avoid this
 * we will only have one segment (segment 0) working for this case - enforced with isWorkingSegment() method.
 * Naturaly this is the less recomended working mode since we are not making use of segement parallelism.
 * Acessors for a specific file type should inherit from this class only if the file they are reading does 
 * not suport splitting: a protocol-buffer file, regular file, ...
*/
public abstract class OddFileAccessor implements IHdfsFileAccessor
{
	private Configuration conf = null; 
	protected HDFSMetaData metaData = null;
	protected InputStream inp = null;

	/*
	 * C'tor
	 */ 	
	public OddFileAccessor(HDFSMetaData meta) throws Exception
	{
		// 0. Hold the configuration data
		metaData = meta;
				
		// 1. Load Hadoop configuration defined in $HADOOP_HOME/conf/*.xml files
		conf = new Configuration();
	}

	/*
	 * Open
	 * Opens the file the file, using the non-splittable API for HADOOP HDFS file access
	 * This means that instead of using a FileInputFormat for access, we use a Java stream
	 */	
	public boolean Open() throws Exception
	{
		if (!isWorkingSegment())
			return false;
		
		// 1. input data stream
		FileSystem  fs = FileSystem.get(URI.create(metaData.path()), conf); // FileSystem.get actually returns an FSDataInputStream
		inp = fs.open(new Path(metaData.path()));
		return (inp != null);
	}

	/*
	 * LoadNextObject
	 * Fetches one record from the  file. The record is returned as a Java object.
	 */			
	public OneRow LoadNextObject() throws IOException
	{
		if (!isWorkingSegment())
			return null;
		
		return new OneRow(null, new Object());
	}

	/*
	 * Close
	 * When user finished reading the file, it closes the access stream
	 */			
	public void Close() throws Exception
	{
		if (!isWorkingSegment())
			return;
		
		if (inp != null)
			inp.close();
	}
	
	/*
	 * Making sure that only the segment that got assigned the first data
	 * fragment will read the (whole) file.
	 */
	private boolean isWorkingSegment()
	{
		Integer frag0 = new Integer(0);		
		
		if (metaData.getDataFragments().contains(frag0))
			return true;
		
		return false;
	}
}
