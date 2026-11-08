```bash
#!/bin/bash

echo "Starting Hadoop services..."
start-dfs.sh
start-yarn.sh

echo "Creating project directory..."
mkdir -p ~/mapreduce/classes
cd ~/mapreduce || exit

echo "Creating input file..."
cat > input.txt << "EOF"
hello world hello hadoop
hadoop is powerful
mapreduce is scalable
hello mapreduce world
big data processing with hadoop
EOF

echo "Creating WordCount.java..."
cat > WordCount.java << "EOF"
import java.io.IOException;
import java.util.StringTokenizer;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.hadoop.io.*;
import org.apache.hadoop.mapreduce.*;
import org.apache.hadoop.mapreduce.lib.input.*;
import org.apache.hadoop.mapreduce.lib.output.*;

public class WordCount {
    public static class TokenizerMapper
    extends Mapper<Object, Text, Text, IntWritable> {
        private final static IntWritable one = new IntWritable(1);
        private Text word = new Text();

        public void map(Object key, Text value, Context context)
        throws IOException, InterruptedException {
            StringTokenizer itr = new StringTokenizer(value.toString());
            while (itr.hasMoreTokens()) {
                word.set(itr.nextToken());
                context.write(word, one);
            }
        }
    }

    public static class IntSumReducer
    extends Reducer<Text, IntWritable, Text, IntWritable> {
        private IntWritable result = new IntWritable();

        public void reduce(Text key, Iterable<IntWritable> values,
        Context context) throws IOException, InterruptedException {
            int sum = 0;
            for (IntWritable val : values)
                sum += val.get();

            result.set(sum);
            context.write(key, result);
        }
    }

    public static void main(String[] args) throws Exception {
        Configuration conf = new Configuration();
        Job job = Job.getInstance(conf, "word count");

        job.setJarByClass(WordCount.class);
        job.setMapperClass(TokenizerMapper.class);
        job.setCombinerClass(IntSumReducer.class);
        job.setReducerClass(IntSumReducer.class);

        job.setOutputKeyClass(Text.class);
        job.setOutputValueClass(IntWritable.class);

        FileInputFormat.addInputPath(job, new Path(args[0]));
        FileOutputFormat.setOutputPath(job, new Path(args[1]));

        System.exit(job.waitForCompletion(true) ? 0 : 1);
    }
}
EOF

echo "Compiling..."
javac -classpath "$(hadoop classpath)" -d classes WordCount.java

if [ $? -ne 0 ]; then
    echo "Compilation failed"
    exit 1
fi

echo "Creating JAR..."
jar -cvf wordcount.jar -C classes/ .

echo "Cleaning HDFS..."
hdfs dfs -rm -r -f /input /output

echo "Uploading input..."
hdfs dfs -mkdir -p /input
hdfs dfs -put input.txt /input

echo "Running WordCount MapReduce..."
hadoop jar wordcount.jar WordCount /input /output

if [ $? -ne 0 ]; then
    echo "WordCount job failed"
    exit 1
fi

echo "Most Frequent Words and Counts:"
hdfs dfs -cat /output/part-r-00000 | sort -k2,2nr

echo "Program completed!"
```